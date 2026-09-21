import ext/hook
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleeunit
import jevelin
import skill_selector/selection

pub fn main() {
  gleeunit.main()
}

fn context() -> String {
  "{\"op_id\":\"op\",\"messages\":[],\"candidates\":[{\"name\":\"review\",\"description\":\"Review code\",\"excerpt\":\"Check invariants\"},{\"name\":\"frontend\",\"description\":\"Build UI\",\"excerpt\":\"Use a design system\"}]}"
}

pub fn independent_scores_select_only_relevant_candidates_test() {
  let selector =
    hook.OnSelectSkills(fn(context) {
      let assert Ok(selected) =
        selection.evaluate(
          context.candidates,
          "Review this change",
          fn(request) {
            assert request.path == "/v1/systemone"
            let assert Ok(_body) = json.parse(request.body, decode.dynamic)
            Ok(jevelin.HttpResponse(
              200,
              [],
              "{\"model\":\"fixture\",\"answers\":{\"review\":{\"type\":\"noul\",\"noul\":0.95},\"frontend\":{\"type\":\"noul\",\"noul\":0.2}},\"usage\":{\"input_tokens\":10,\"output_tokens\":1}}",
            ))
          },
        )
      selected
    })
  assert hook.answer(selector, context()) == Ok("{\"skills\":[\"review\"]}")
}

pub fn errors_and_missing_answers_never_select_test() {
  let selector =
    hook.OnSelectSkills(fn(context) {
      assert selection.evaluate(context.candidates, "Review", fn(_) {
          Error(Nil)
        })
        == Error(Nil)
      assert selection.evaluate(context.candidates, "Review", fn(_) {
          Ok(jevelin.HttpResponse(
            200,
            [],
            "{\"model\":\"fixture\",\"answers\":{},\"usage\":{\"input_tokens\":0,\"output_tokens\":0}}",
          ))
        })
        == Error(Nil)
      assert selection.evaluate(context.candidates, "", fn(_) {
          panic as "empty task must not call Jev"
        })
        == Ok([])
      []
    })
  assert hook.answer(selector, context()) == Ok("{\"skills\":[]}")
}

pub fn task_excludes_assistant_tool_and_harness_notes_test() {
  let assert Ok(messages) =
    json.parse(
      "[{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"Review this\"}]},{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"secret output\"}]},{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"[loom] note\"}]}]",
      decode.list(decode.dynamic),
    )
  assert selection.task(messages) == "Review this"
}

pub fn cache_identity_changes_with_task_and_operation_test() {
  let selector =
    hook.OnSelectSkills(fn(context) {
      assert selection.identity(context, "old")
        != selection.identity(context, "new")
      assert selection.identity(context, "old")
        != selection.identity(
          hook.SkillContext(..context, op_id: "other"),
          "old",
        )
      assert selection.resolve(context.candidates, ["unknown"]) == []
      assert list.length(selection.resolve(context.candidates, ["review"])) == 1
      []
    })
  assert hook.answer(selector, context()) == Ok("{\"skills\":[]}")
}

pub fn native_injections_and_images_do_not_replace_the_task_test() {
  let texts = [
    "Your own notes for strand `main`: old confidential notes",
    "Distilled memory from this repository's earlier sessions: confidential",
    "[SessionStart hook] background context", "[Stop hook] resume notes",
    "[PostToolUse hook] contextual hint",
  ]
  let task =
    json.object([
      #("role", json.string("user")),
      #(
        "content",
        json.array(
          [
            json.object([
              #("type", json.string("image")),
              #("data", json.string("ignored")),
            ]),
            json.object([
              #("type", json.string("text")),
              #("text", json.string("Build the UI")),
            ]),
          ],
          fn(value) { value },
        ),
      ),
    ])
  let notes =
    list.map(texts, fn(text) {
      json.object([
        #("role", json.string("user")),
        #(
          "content",
          json.array(
            [
              json.object([
                #("type", json.string("text")),
                #("text", json.string(text)),
              ]),
            ],
            fn(value) { value },
          ),
        ),
      ])
    })
  let assert Ok(messages) =
    json.parse(
      json.to_string(json.array([task, ..notes], fn(value) { value })),
      decode.list(decode.dynamic),
    )
  assert selection.task(messages) == "Build the UI"
}
