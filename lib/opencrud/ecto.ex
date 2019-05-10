import Ecto.Query

defmodule OpenCrud.Ecto do
  alias Absinthe.Relay

  # extracted from Abisinthe.Relay
  def paginate(query, args, opts \\ []) do
    require Ecto.Query

    with {:ok, offset, limit} <- Relay.Connection.offset_and_limit_for_query(args, opts) do
      query
        |> Ecto.Query.limit(^(limit + 1))
        |> Ecto.Query.offset(^offset)
    else
      {:error, _ } -> query
    end
  end

  @spec make_connections(any(), %{after: nil | integer(), before: nil | integer(), first: nil | integer(), last: nil | integer()}, [{:count, non_neg_integer()} | {:has_next_page, boolean()} | {:has_previous_page, boolean()}]) :: {:error, <<_::64, _::_*8>>} | {:ok, %{edges: [map()], page_info: %{end_cursor: binary(), has_next_page: boolean(), has_previous_page: boolean(), start_cursor: binary()}}}
  def make_connections(records, args, opts \\ []) do
    require Ecto.Query

    with {:ok, offset, limit} <- Relay.Connection.offset_and_limit_for_query(args, opts) do
      opts =
        opts
        |> Keyword.put(:has_previous_page, offset > 0)
        |> Keyword.put(:has_next_page, length(records) > limit)

      Relay.Connection.from_slice(Enum.take(records, limit), offset, opts)
    end
  end

  def filter(query,args) do
    require Ecto.Query

    if args[:where][:id_in] do

      id_list = Enum.map(args[:where][:id_in],fn enc_id ->
        with {:ok, %{id: id, type: type}} <- Relay.Node.from_global_id(enc_id, RectangleWeb.Schema) do
          id
        end
        # FIXME: handle errors
      end)

      where(query, [a], a.id in ^id_list)
    else
      query
    end
  end

  def get(query, repo, args, context) do
    {status, %{id: id, type: type}} = Relay.Node.from_global_id(args[:where][:id],RectangleWeb.Schema)

    {:ok, repo.get(query, id)}
  end

  def update(type, repo, schema, %{data: data, where: where}, _) do
    with {:ok, %{id: id, type: type}} <- Relay.Node.from_global_id(where[:id], schema) do
      repo.get(type, id)
      |> type.changeset(Map.merge(data, belongs_to_associations(type, data)))
      |> repo.update
    end
    # FIXME: handle errors
  end

  defp connected_objects data do
    data
    |> Enum.filter(fn c -> is_map(elem(c,1)) && Map.has_key?(elem(c,1), :connect) end)
    |> Enum.map(fn k -> {elem(k,0), Relay.Node.from_global_id(elem(k,1)[:connect][:id],RectangleWeb.Schema) |> elem(1)} end)
    |> Map.new
  end

  defp belongs_to(type) do
    type.__changeset__
    |> Enum.filter(fn c -> is_tuple(elem(c,1)) end)
    |> Enum.filter(fn c -> is_tuple(elem(c,1)) end)
    |> Enum.map(fn c -> elem(c,1) end)
    |> Keyword.values()
    |> Enum.filter(&match?(%Ecto.Association.BelongsTo{}, &1))
  end

  defp belongs_to_associations(type, data) do
    keys = connected_objects(data)

    belongs_to(type)
    |> Enum.map(fn c -> {c.owner_key, keys[c.field][:id]} end)
    |> Map.new
  end

  def create(type, repo, %{data: data}, _) do
    struct(type)
    |> type.changeset(Map.merge(data, belongs_to_associations(type, data)))
    |> repo.insert
  end

  defp field_list(context, name) do
    context
    |> Absinthe.Resolution.project
    |> Enum.filter(fn a -> a.name == name end)
    |> Enum.flat_map(fn a -> a.selections end)
    |> Enum.map(fn a -> a.name end)
    |> Enum.map(fn a -> String.to_atom(a) end)
  end

  def connection_wrapper(args, context, aggregates_func, edges_func) do
    edges_fields = field_list(context, "edges")
    edges = if length(edges_fields) > 0 do
      edges_func.(args,context)
      |> elem(1)
      |> make_connections(args)
    else
      {:ok, %{}}
    end

    aggregate_fields = field_list(context, "aggregate")
    aggregates = if length(aggregate_fields) > 0 do
      aggregates_func.(args, context)
      |> elem(1)
    else
      %{}
    end

    {:ok, Map.merge(elem(edges,1), %{ aggregate: aggregates })}
  end
end
