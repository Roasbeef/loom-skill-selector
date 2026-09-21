//// The installed hook uses only brokered HTTP and extension-owned memory.
//// The credential is injected by Loom at the approved origin. Neither the
//// request nor the satellite reads an environment variable or opens a socket.

import cap/net
import ext/hook
import ext/memory
import gleam/bit_array
import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}
import gleam/result
import jevelin
import skill_selector/selection

/// The entry point named by extension.toml.
///
/// ## Examples
///
/// ```gleam
/// assert hook.event(on_event()) == "select_skills"
/// ```
pub fn on_event() -> hook.Hook {
  hook.OnSelectSkills(select)
}

fn select(context: hook.SkillContext) -> List(hook.SkillCandidate) {
  let task = selection.task(context.messages)
  let identity = selection.identity(context, task)
  case cached(identity) {
    Ok(names) -> selection.resolve(context.candidates, names)
    Error(Nil) -> {
      let selected =
        selection.evaluate(context.candidates, task, transport)
        |> result.unwrap([])
      let _saved =
        memory.remember(
          "selection",
          json.object([
            #("identity", json.string(identity)),
            #(
              "names",
              json.array(selected, fn(candidate) {
                json.string(hook.skill_name(candidate))
              }),
            ),
          ]),
        )
      selected
    }
  }
}

fn cached(identity: String) -> Result(List(String), Nil) {
  use value <- result.try(
    memory.recall("selection") |> result.replace_error(Nil),
  )
  use value <- result.try(case value {
    Some(value) -> Ok(value)
    None -> Error(Nil)
  })
  let decoder = {
    use key <- decode.field("identity", decode.string)
    use names <- decode.field("names", decode.list(decode.string))
    decode.success(#(key, names))
  }
  use pair <- result.try(
    decode.run(value, decoder) |> result.replace_error(Nil),
  )
  case pair.0 == identity {
    True -> Ok(pair.1)
    False -> Error(Nil)
  }
}

fn transport(
  request: jevelin.HttpRequest,
) -> Result(jevelin.HttpResponse, Nil) {
  use response <- result.try(
    net.request(net.Request(
      method: "POST",
      url: jevelin.origin <> request.path,
      headers: request.headers,
      body: bit_array.from_string(request.body),
    ))
    |> result.replace_error(Nil),
  )
  use body <- result.try(bit_array.to_string(response.body))
  Ok(jevelin.HttpResponse(response.status, response.headers, body))
}
