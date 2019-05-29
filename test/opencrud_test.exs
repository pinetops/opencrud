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

    @books %{
      "1" => %{
        id: "1",
        title: "A Game of Thrones",
        author_id: "1"
      },
      "2" => %{
        id: "2",
        title: "A Clash of Kings",
        author_id: "2"
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

    opencrud_object :author do
      field :first_name, non_null(:string)
      field :last_name, :string
    end

    opencrud_object :book do
      field :title, non_null(:string)
      field :author, non_null(:author)
      #, resolve: fn a ->
      #  {:ok, Enum.map(Enum.find(@authors, fn a ->elem(a, 1).id , fn a -> elem(a, 1) end)}
      #end
    end

    query do
      opencrud_get :author do
        resolve fn
          %{where: %{ id: id }}, _ ->
            {:ok, Enum.find(@authors, fn a -> id == elem(a, 1).id end) |> elem(1)}
          _, _ ->
            {:error, "Not found"}
        end
      end

      opencrud_list :author do
        resolve_aggregate fn
          _, _ ->
            {:ok, %{count: Enum.count(@authors)}}
        end

        resolve_list fn
          %{where: %{ id_in: ids }}, _ ->
            {:ok, Enum.map(Enum.filter(@authors, fn a -> Enum.member?(ids, elem(a, 1).id) end) , fn a -> elem(a, 1) end)}
          %{where: %{ first_name: first_name }}, _ ->
            {:ok, Enum.map(Enum.filter(@authors, fn a -> elem(a, 1).first_name == first_name end) , fn a -> elem(a, 1) end)}
          _, _ ->
            {:ok, Enum.map(@authors, fn a -> elem(a, 1) end)}
        end

        where do
          field :first_name, :string
        end
      end

      opencrud_list :book do
        resolve_aggregate fn
          _, _ ->
            {:ok, %{count: Enum.count(@books)}}
        end

        resolve_list fn
          %{where: %{ id_in: ids }}, _ ->
            {:ok, Enum.map(Enum.filter(@books, fn a -> Enum.member?(ids, elem(a, 1).id) end) , fn a -> elem(a, 1) end)}
          %{where: %{ author: %{ id: author_id }}}, _ ->
           {:ok, Enum.map(Enum.filter(@books, fn a -> elem(a, 1).author_id == author_id.id end) , fn a -> elem(a, 1) end)}
            _, _ ->
            {:ok, Enum.map(@authors, fn a -> elem(a, 1) end)}
        end

        middleware Absinthe.Relay.Node.ParseIDs, where: [author: [id: [:author]]]

        where do
          field :title, :string
          field :author, :author_where_unique_input
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

    test " allows querying objects by id" do
      result =
        """
          query author($where: AuthorWhereUniqueInput) {
            author: author(where: $where)  {
              id
              first_name,
              last_name,
              __typename
            }
          }

        """
        |> Absinthe.run(
          ASimpleTypeSchema,
          variables: %{"where" => %{ "id" => "QXV0aG9yOjE="}}
        )

      assert {:ok,
              %{
                data: %{
                  "author" =>
                    %{
                      "__typename" => "Author",
                      "first_name" => "Brian",
                      "id" => "QXV0aG9yOjE=",
                      "last_name" => "Phelps"
                    }
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

    test " allows querying objects by where block" do
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
          variables: %{"first" => 5, "where" => %{ "first_name" => "Andrew"}}
        )

      assert {:ok,
              %{
                data: %{
                  "items" => [
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

    test " allows querying objects by reference" do
      result =
        """
          query books($first: Int, $where: BookWhereInput) {
            items: books(first: $first, where: $where)  {
              id,
              title
              __typename
            }
          }

        """
        |> Absinthe.run(
          ASimpleTypeSchema,
          variables: %{"first" => 5, "where" => %{ "author" => %{ "id" => "QXV0aG9yOjE="}}}
        )

      assert {:ok,
              %{
                data: %{
                  "items" => [
                    %{
                      "__typename" => "Book",
                      "id" => "Qm9vazox",
                      "title" => "A Game of Thrones"
                    }
                  ]
                }
              }} == result
    end
  end
end
