defmodule OpenCrud.Notation do
  use Absinthe.Schema.Notation
  alias Absinthe.Schema.Notation

  defmacro opencrud_object(type, do: block) do
    do_object(__CALLER__, type, block)
  end

  defmacro opencrud_get(type, do: block) do
    do_node_query(__CALLER__, type, block)
  end

  defmacro opencrud_list(type, do: block) do
    do_list(__CALLER__, type, block)
  end

  defmacro opencrud_update(type, do: block) do
    do_update(__CALLER__, type, block)
  end

  defmacro opencrud_create(type, do: block) do
    do_create(__CALLER__, type, block)
  end

  defp do_object(env, type, block) do
    record_connection!(env, type, block)
    record_object!(env, type, block)
    record_aggregate!(env, type, block)
    record_edge!(env, type, block)
    record_where_unique_input!(env, type, block)
    record_update_input!(env, type, block)
    record_create_input!(env, type, block)
    record_field_create_one_without_type_input!(env, type, block)
  end

  def record_object!(env, type, block) do
    name = type |> Atom.to_string() |> Absinthe.Utils.camelize()

    Notation.record_object!(env, type, [], [
      object_body(name),
      block
    ])

    Notation.desc_attribute_recorder(type)
  end

  defp object_body(name) do
    quote do
      @desc "The ID of an object"
      field :id, non_null(:id) do
        resolve Absinthe.Relay.Node.global_id_resolver(unquote(name), nil)
      end

      interface(:node)
    end
  end

  def record_aggregate!(env, type, _) do
    type = "aggregate_#{Inflex.pluralize(type)}" |> String.to_atom()

    Notation.record_object!(env, type, [], [
      aggregate_body()
    ])
  end

  defp aggregate_body() do
    quote do
      field :count, non_null(:integer)
    end
  end

  def record_where_unique_input!(env, type, _) do
    type = "#{type}_where_unique_input" |> String.to_atom()

    Notation.record_input_object!(env, type, [], [
      where_unique_input_body()
    ])
  end

  defp where_unique_input_body() do
    quote do
      field :id, non_null(:id)
    end
  end

  def record_update_input!(env, type, block) do
    type_name = "#{type}_update_input" |> String.to_atom()

    # FIXME: allow non-required variation
    block = rewrite_fields("update_one_required_without_#{type}s_input", block)

    Notation.record_input_object!(env, type_name, [], [
      block
    ])
  end

  defp replace_type(field_name, replacement, block) do
    #  {:__block__, [],
    #  [
    #    {:field, [line: 28], [:title, {:non_null, [line: 28], [:string]}]},
    #    {:field, [line: 29], [:technique, :string]},
    #    {:field, [line: 30], [:artist, {:non_null, [line: 30], [:artist]}]}
    #  ]}

    type_path = [
      Access.elem(2),
      Access.filter(fn b ->
        elem(b, 0) == :field &&
          elem(b, 2) |> Enum.at(0) == field_name &&
          elem(b, 2) |> Enum.at(1) |> is_tuple
      end),
      Access.elem(2),
      Access.at(1),
      Access.elem(2),
      Access.at(0)
    ]

    name_path = [
      Access.elem(2),
      Access.filter(fn b ->
        elem(b, 0) == :field &&
          elem(b, 2) |> Enum.at(0) == field_name &&
          !(elem(b, 2) |> Enum.at(1) |> is_tuple)
      end),
      Access.elem(2)
    ]

    block
    |> put_in(name_path, "#{field_name}_#{replacement}" |> String.to_atom())
    |> put_in(type_path, "#{field_name}_#{replacement}" |> String.to_atom())
  end

  def field_type(field_data) do
    if get_in(field_data, [Access.at(1)]) |> is_tuple do
      get_in(field_data, [Access.at(1), Access.elem(2), Access.at(0)])
    else
      get_in(field_data, [Access.at(1)])
    end
  end

  def field_name(field_data) do
    get_in(field_data, [Access.at(0)])
  end

  def rewrite_fields(replacement, block) do
    path = [
      Access.elem(2),
      Access.filter(fn b -> elem(b, 0) == :field end),
      Access.elem(2)
    ]

    get_in(block, path)
    # FIXME: check for other primitive types
    |> Enum.filter(fn a -> field_type(a) != :string end)
    |> Enum.reduce(block, fn a, acc -> replace_type(field_name(a), replacement, acc) end)
  end

  def record_create_input!(env, type, block) do
    block = rewrite_fields("create_one_without_#{Inflex.pluralize(type)}_input", block)

    type = "#{type}_create_input" |> String.to_atom()

    Notation.record_input_object!(env, type, [], [
      create_input_body(),
      block
    ])
  end

  defp create_input_body() do
    quote do
      field :id, :id
    end
  end

  def record_field_create_one_without_type_input!(env, type, block) do
    # FIXME: handle missing update types
    # FIXME: handle no-required updates

    path = [
      Access.elem(2),
      Access.filter(fn b -> elem(b, 0) == :field end),
      Access.elem(2)
    ]

    get_in(block, path)
    # FIXME: check for other primitive types
    |> Enum.filter(fn a -> field_type(a) != :string end)
    |> Enum.map(fn a -> field_name(a) end)
    |> Enum.map(fn a ->
      type_to_pass = "#{a}_create_one_without_#{Inflex.pluralize(type)}_input" |> String.to_atom()

      Notation.record_input_object!(env, type_to_pass, [], [
        field_create_update_one_without_type_input_body(a)
      ])

      type_to_pass = "#{a}_update_one_required_without_#{Inflex.pluralize(type)}_input" |> String.to_atom()

      Notation.record_input_object!(env, type_to_pass, [], [
        field_create_update_one_without_type_input_body(a)
      ])
    end)
  end

  defp field_create_update_one_without_type_input_body(field_name) do
    # FIXME: Add handling for create
    quote do
      field :connect, unquote("#{field_name}_where_unique_input" |> String.to_atom())
    end
  end

  def record_connection!(env, type, _) do
    Notation.record_object!(env, "#{type}_connection" |> String.to_atom(), [], [
      connection_body(type)
    ])
  end

  defp connection_body(type) do
    quote do
      field :aggregate, unquote("aggregate_#{Inflex.pluralize(type)}" |> String.to_atom())
      field :edges, non_null(list_of(non_null(unquote("#{type}_edge" |> String.to_atom()))))
    end
  end

  def record_edge!(env, type, _) do
    Notation.record_object!(env, "#{type}_edge" |> String.to_atom(), [], [
      edge_body(type)
    ])
  end

  defp edge_body(type) do
    quote do
      field :node, unquote(type)
      field :cursor, non_null(:string)
    end
  end

  defp quoted_list_type(type) do
    quote do: non_null(list_of(non_null(unquote(type))))
  end

  defp do_node_query(env, type, block) do
    record_node_query!(env, type, block)
  end

  def record_node_query!(env, type, block) do
    env
    |> Notation.recordable!(:field)
    |> Notation.record_field!(type, [type: type], [
      node_query_body(type, block)
    ])
  end

  defp node_query_body(type, block) do
    quote do
      arg(:where, unquote("#{type}_where_unique_input" |> String.to_atom()))

      # FIXME: This would be better put on the input object directly, but
      #        the API doesn't appear to support that
      middleware Absinthe.Relay.Node.ParseIDs, where: [id: unquote(type)]

      unquote(block)
    end
  end

  defp do_list(env, type, block) do
    record_list!(env, type, block)
  end

  defp naming_from_attrs!(attrs) do
    naming =
      Absinthe.Relay.Connection.Notation.Naming.define(attrs[:node_type], attrs[:connection])

    naming ||
      raise(
        "Must provide a `:node_type' option (an optional `:connection` option is also supported)"
      )
  end

  def record_list!(env, type, block) do
    resolve_list =
      Macro.prewalk(block, [], fn
        {:resolve_list, x, y}, b -> {0, b ++ {:resolve_list, x, y}}
        node, b -> {node, b}
      end)
      |> elem(1)
      |> elem(2)
      |> Enum.at(0)

    # FIXME: check whether that should really be ':aggregate'
    resolve_aggregate =
      Macro.prewalk(block, [], fn
        {:resolve_aggregate, x, y}, b -> {0, b ++ {:aggregate, x, y}}
        node, b -> {node, b}
      end)
      |> elem(1)
      |> elem(2)
      |> Enum.at(0)

    block_without_where =
      Macro.prewalk(block, [], fn
        {:where, x, y}, b -> {nil, b}
        node, b -> {node, b}
      end)

    env
    |> Notation.recordable!(:field)
    |> Notation.record_field!(Inflex.pluralize(type) |> String.to_atom(), [type: quoted_list_type(type)], [
      list_query_body(type, resolve_list, block)
    ])

    # FIXME: Support args
    env
    |> Notation.recordable!(:field)
    |> Absinthe.Relay.Connection.Notation.record_connection_field!(
      "#{Inflex.pluralize(type)}_connection" |> String.to_atom(),
      naming_from_attrs!(node_type: type),
      [],
      [
        node_connection_body(type, resolve_list, resolve_aggregate, block_without_where)
      ]
    )
  end

  defp list_query_body(type, resolve_list, block) do
    quote do
      arg :after, :string
      arg :before, :string
      arg :first, :integer
      arg :last, :integer
      arg :where, unquote("#{type}_where_input" |> String.to_atom())

      # FIXME: This would be better put on the input object directly, but
      #        the API doesn't appear to support that
      middleware Absinthe.Relay.Node.ParseIDs, where: [id_in: unquote(type)]

      private(OpenCrud, :where_field_identifier, unquote(type))
      unquote(block)

      # FIXME: why does this need to be last?
      resolve(unquote(resolve_list))
    end
  end

  defp node_connection_body(type, resolve_list, resolve_aggregate, block) do
    quote do
      arg :where, unquote("#{type}_where_input" |> String.to_atom())

      # FIXME: This would be better put on the input object directly, but
      #        the API doesn't appear to support that
      middleware Absinthe.Relay.Node.ParseIDs, where: [id_in: unquote(type)]

      private(Absinthe.Relay, :where_field_identifier, unquote(type))
      unquote(block)

      resolve fn
        args, context ->
          OpenCrud.Ecto.connection_wrapper(
            args,
            context,
            unquote(resolve_aggregate),
            unquote(resolve_list)
          )
      end
    end
  end

  defp do_update(env, type, block) do
    record_update!(env, type, block)
  end

  def record_update!(env, type, block) do
    update_identifier = "update_#{type}" |> String.to_atom()

    env
    |> Notation.recordable!(:field)
    |> Notation.record_field!(update_identifier, [type: type], [
      update_body(type),
      block
    ])
  end

  defp update_body(type) do
    quote do
      arg :data, non_null(unquote("#{type}_update_input" |> String.to_atom()))
      arg :where, non_null(unquote("#{type}_where_unique_input" |> String.to_atom()))
    end
  end

  defp do_create(env, type, block) do
    record_create!(env, type, block)
  end

  def record_create!(env, type, block) do
    create_identifier = "create_#{type}" |> String.to_atom()

    env
    |> Notation.recordable!(:field)
    |> Notation.record_field!(create_identifier, [type: type], [
      create_body(type),
      block
    ])
  end

  defp create_body(type) do
    quote do
      arg :data, non_null(unquote("#{type}_create_input" |> String.to_atom()))
    end
  end

  defmacro resolve_list(_, do: block) do

  end

  defmacro resolve_aggregate(_, do: block) do

  end

  @private_field_identifier_path [OpenCrud, :where_field_identifier]

  defmacro where(do: block) do
    env = __CALLER__
    base_identifier = Notation.get_in_private(env.module, @private_field_identifier_path)

    record_input_object!(env, base_identifier, block)
  end

  def record_input_object!(env, base_identifier, block) do
    identifier = "#{base_identifier}_where_input" |> String.to_atom()

    Notation.record_input_object!(env, identifier, [], where_body(block))
  end

  defp where_body(block) do
    quote do
      field :id_in, list_of(non_null(:id))

      unquote(block)
    end
  end
end
