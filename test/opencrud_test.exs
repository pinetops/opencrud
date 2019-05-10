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
          args, context ->
            {:ok, %{count: Enum.count(@authors)}}
          end

        resolve_list fn
          args, context ->
            {:ok, Enum.map(@authors, fn a -> elem(a, 1) end)}
          end
      end
    end
  end

  describe "Defining object and connection fields" do
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
