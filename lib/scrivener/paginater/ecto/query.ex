defimpl Scrivener.Paginater, for: Ecto.Query do
  import Ecto.Query

  alias Scrivener.{Config, Page}

  @moduledoc false

  @spec paginate(Ecto.Query.t, Scrivener.Config.t) :: Scrivener.Page.t
  def paginate(query, %Config{page_size: page_size, page_number: page_number, module: repo, caller: caller}) do
    total_entries = total_entries(query, repo, caller)

    %Page{
      page_size: page_size,
      page_number: page_number,
      entries: entries(query, repo, page_number, page_size, caller),
      total_entries: total_entries,
      total_pages: total_pages(total_entries, page_size)
    }
  end

  defp entries(query, repo, page_number, page_size, caller) do
    offset = page_size * (page_number - 1)

    query
    |> limit(^page_size)
    |> offset(^offset)
    |> repo.all(caller: caller)
  end

  defp total_entries(query, repo, caller) do
    total_entries =
      query
      |> exclude(:preload)
      |> exclude(:order_by)
      |> prepare_select
      |> count
      |> repo.one(caller: caller)

    total_entries || 0
  end

  defp prepare_select(query) do
    try do
      query
      |> count
      |> Ecto.Query.Planner.prepare_sources(nil)

      query
    rescue
      e in Ecto.SubQueryError ->
        case e do
          %{
            exception: %{
              message: "subquery must select a source (t), a field (t.field) or a map" <> _rest
            }
          } ->
            query
            |> exclude(:select)
          _ ->
            raise e
        end
    end
  end

  defp count(query) do
    query
    |> subquery
    |> select(count("*"))
  end

  defp total_pages(0, _), do: 1

  defp total_pages(total_entries, page_size) do
    (total_entries / page_size) |> Float.ceil |> round
  end
end
