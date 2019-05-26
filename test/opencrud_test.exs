defmodule OpencrudTest do
  use ExUnit.Case
  doctest Opencrud

  defmodule ASimpleTypeSchema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema, :modern
    import OpenCrud.Notation

    @authors %{
      "1" => %{
        id: "1",
        first_name: "Brian",
        last_name: "Phelps"
      },
      "2" => %{
        id: "2",
        first_name: "Andrew",
        last_name: "Sparrow"
      }
    }

    node interface do
      resolve_type(fn
        %{}, _ ->
          :link

        _, _ ->
          nil
      end)
    end

    opencrud_node :author do
      field :first_name, non_null(:string)
      field :last_name, :string
    end

    query do
      opencrud_list :author do
        resolve_aggregate fn
          _, _ ->
            {:ok, %{count: Enum.count(@authors)}}
        end

        resolve_list fn
          %{where: %{ id_in: ids }}, _ ->
            ids = Enum.map(ids, fn enc_id ->
              with {:ok, %{id: id, type: _type}} <-
                Absinthe.Relay.Node.from_global_id(enc_id, __MODULE__) do
                  id
                end
            end)

            {:ok, Enum.map(Enum.filter(@authors, fn a -> Enum.member?(ids, elem(a, 1).id) end) , fn a -> elem(a, 1) end)}
          _, _ ->

            {:ok, Enum.map(@authors, fn a -> elem(a, 1) end)}
        end
      end
    end
  end

  describe "Defining object and connection fields" do
    test " allows querying objects" do
      result =
        """
          query authors($first: Int) {
            items: authors(first: $first)  {
              id
              first_name,
              last_name,
              __typename
            }
          }

        """
        |> Absinthe.run(
          ASimpleTypeSchema,
          variables: %{"first" => 5}
        )

      assert {:ok,
              %{
                data: %{
                  "items" => [
                    %{
                      "__typename" => "Author",
                      "first_name" => "Brian",
                      "id" => "QXV0aG9yOjE=",
                      "last_name" => "Phelps"
                    },
                    %{
                      "__typename" => "Author",
                      "first_name" => "Andrew",
                      "id" => "QXV0aG9yOjI=",
                      "last_name" => "Sparrow"
                    }
                  ]
                }
              }} == result
    end

    test " allows querying objects by ids" do
      result =
        """
          query authors($first: Int, $where: AuthorWhereInput) {
            items: authors(first: $first, where: $where)  {
              id
              first_name,
              last_name,
              __typename
            }
          }

        """
        |> Absinthe.run(
          ASimpleTypeSchema,
          variables: %{"first" => 5, "where" => %{ "idIn" => [ "QXV0aG9yOjE="]}}
        )

      assert {:ok,
              %{
                data: %{
                  "items" => [
                    %{
                      "__typename" => "Author",
                      "first_name" => "Brian",
                      "id" => "QXV0aG9yOjE=",
                      "last_name" => "Phelps"
                    }
                  ]
                }
              }} == result
    end

    test " allows querying connection and aggregates" do
      result =
        """
          query authors($first: Int) {
            total: authorsConnection(first: $first)  {
              aggregate {
                count
                __typename
              }
              edges{
                node {
                  id
                  first_name
                  last_name
                }
              }
              __typename
            }
          }

        """
        |> Absinthe.run(
          ASimpleTypeSchema,
          variables: %{"first" => 5}
        )

      assert {:ok,
              %{
                data: %{
                  "total" => %{
                    "__typename" => "AuthorConnection",
                    "aggregate" => %{"__typename" => "AggregateAuthors", "count" => 2},
                    "edges" => [
                      %{
                        "node" => %{
                          "first_name" => "Brian",
                          "id" => "QXV0aG9yOjE=",
                          "last_name" => "Phelps"
                        }
                      },
                      %{
                        "node" => %{
                          "first_name" => "Andrew",
                          "id" => "QXV0aG9yOjI=",
                          "last_name" => "Sparrow"
                        }
                      }
                    ]
                  }
                }
              }} == result
    end
  end
end
