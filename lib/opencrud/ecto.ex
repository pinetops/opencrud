import Ecto.Query

defmodule OpenCrud.Ecto do
  alias Absinthe.Relay

  # extracted from Abisinthe.Relay

  def page!(args, opts \\ []) do
    if args[:first] && args[:skip] do
      %{:offset => args[:skip], :limit => args[:skip] + args[:first] - 1}
    else
      with {:ok, offset, limit} <- Relay.Connection.offset_and_limit_for_query(args, opts) do
        %{:offset => offset, :limit => limit}
      else
        {:error, _error} -> nil
      end
    end
  end

  def paginate(query, %{:offset => offset, :limit => limit}) do
    query
    |> Ecto.Query.limit(^(limit + 1))
    |> Ecto.Query.offset(^offset)
  end

  def paginate(query, nil) do
    query
  end

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

  def filter(query, %{where: %{id_in: id_list}}, _) do
    require Ecto.Query

    where(query, [a], a.id in ^id_list)
  end

  def filter(query, _, _) do
    query
  end

  def get(query, repo, %{where: %{id: id}}, _) do
    {:ok, repo.get(query, id)}
  end

  def id_query(query, input, context) do
    require Ecto.Query

    with {:ok, %{id: id}} <- Relay.Node.from_global_id(input.where[:id], context.schema) do
      where(query, [a], a.id == ^id)
    end
    # FIXME: handle errors
  end

  def update_changeset(struct, input, context) do
    %name{} = struct

    struct
    |> name.changeset(Map.merge(input.data, belongs_to_associations(name, input.data, context)))
  end

  defp connected_objects(data, context) do
    data
    |> Enum.filter(fn c -> is_map(elem(c, 1)) && Map.has_key?(elem(c, 1), :connect) end)
    |> Enum.map(fn k ->
      {elem(k, 0),
       Relay.Node.from_global_id(elem(k, 1)[:connect][:id], context.schema) |> elem(1)}
    end)
    |> Map.new()
  end

  defp belongs_to(type) do
    type.__changeset__
    |> Enum.filter(fn c -> is_tuple(elem(c, 1)) end)
    |> Enum.filter(fn c -> is_tuple(elem(c, 1)) end)
    |> Enum.map(fn c -> elem(c, 1) end)
    |> Keyword.values()
    |> Enum.filter(&match?(%Ecto.Association.BelongsTo{}, &1))
  end

  defp belongs_to_associations(type, data, context) do
    keys = connected_objects(data, context)

    belongs_to(type)
    |> Enum.map(fn c -> {c.owner_key, keys[c.field][:id]} end)
    |> Map.new()
  end

  def create_changeset(type, %{data: data}, context) do
    struct(type)
    |> type.changeset(Map.merge(data, belongs_to_associations(type, data, context)))
  end

  defp field_list(context, name) do
    context
    |> Absinthe.Resolution.project()
    |> Enum.filter(fn a -> a.name == name end)
    |> Enum.flat_map(fn a -> a.selections end)
    |> Enum.map(fn a -> a.name end)
    |> Enum.map(fn a -> String.to_atom(a) end)
  end

  def connection_wrapper(args, context, aggregates_func, edges_func) do
    edges_fields = field_list(context, "edges")

    edges =
      if length(edges_fields) > 0 do
        edges_func.(args, context)
        |> elem(1)
        |> make_connections(args)
      else
        {:ok, %{}}
      end

    aggregate_fields = field_list(context, "aggregate")

    aggregates =
      if length(aggregate_fields) > 0 do
        aggregates_func.(args, context)
        |> elem(1)
      else
        %{}
      end

    {:ok, Map.merge(elem(edges, 1), %{aggregate: aggregates})}
  end
end
