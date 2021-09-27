defmodule MixUnused.Exports do
  @moduledoc false

  @type t() :: %{mfa() => metadata()} | [{mfa(), metadata()}]
  @type metadata() :: %{
          file: String.t()
        }

  @types ~w[function macro]a

  @spec fetch(module()) :: [{mfa(), metadata()}]
  def fetch(module) do
    # Check exported functions without loading modules as this could cause
    # unexpected behaviours in case of `on_load` callbacks
    with path when is_list(path) <- :code.which(module),
         {:ok, {^module, data}} <- :beam_lib.chunks(path, [:attributes, :compile_info]),
         {:docs_v1, _anno, _lang, _format, _mod_doc, _meta, docs} <-
           Code.fetch_docs(to_string(path)) do
      callbacks = data[:attributes] |> Keyword.get(:behaviour, []) |> callbacks()
      source = Keyword.get(data[:compile_info], :source, "nofile") |> to_string()

      for {{type, name, arity}, anno, _sig, _doc, meta} when type in @types <- docs,
          not Map.get(meta, :export, false),
          {name, arity} not in callbacks do
        line = :erl_anno.line(anno)
        {{module, name, arity}, %{file: source, line: line}}
      end
    else
      _ -> []
    end
  end

  defp callbacks(behaviours) do
    # We need to load behaviours as there is no other way to get list of
    # callbacks than to call `behaviour_info/1`
    Enum.flat_map(behaviours, & &1.behaviour_info(:callbacks))
  end
end