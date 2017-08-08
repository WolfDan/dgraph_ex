defmodule DgraphEx.Query do
   alias DgraphEx.{
    Field,
    Query,
  }
  alias Query.{
    Mutation,
    Schema,
    As,
    Var,
    Func,
    MutationSet,
    Filter,
    Block,
    # Select,
    Groupby,
  }

  @bracketed [
    As,
    Var,
    Groupby,
    Func,
  ]

  defstruct [
    sequence: [],
  ]

  defmacro __using__(_) do
    quote do
      alias DgraphEx.Query
      alias Query.{Kwargs}

      def query() do
        %Query{}
      end

      def query(kwargs) when is_list(kwargs) do
        kwargs
        |> Kwargs.query
      end

      def render(x) do
        x
        |> Query.render
        |> only_spaces
      end

      defp only_spaces(item) when is_binary(item) do
        item
        |> String.replace(~r/(\s+)/,  " ")
        |> String.trim
      end

      def assemble(x) do
        Query.assemble(x)
      end
    end
  end

  def merge(%Query{sequence: seq1}, %Query{sequence: seq2}) do
    %Query{sequence: seq2 ++ seq1 }
  end

  def put_sequence(%__MODULE__{sequence: prev_sequence} = d, prefix) when is_list(prefix) do
    %{ d | sequence: prefix ++ prev_sequence }
  end
  def put_sequence(%__MODULE__{sequence: sequence} = d, item) do
    %{ d | sequence: [ item | sequence ]  }
  end

  def render(%__MODULE__{sequence: seq}) do
    case seq |> Enum.reverse |> assemble do
      [ %Block{keywords: [{:func, _ } | _ ]} | _ ] = assembled ->
        assembled
        |> render_assembled
        |> with_brackets
      [ %{__struct__: module} | _ ] = assembled when module in @bracketed ->
        assembled
        |> render_assembled
        |> with_brackets
      assembled when is_list(assembled) ->
        assembled
        |> render_assembled
      %{__struct__: module} = model ->
        module.render(model)
    end
  end

  def render(block) when is_tuple(block) do
    Block.render(block)
  end

  def render(%{__struct__: module} = model) do
    module.render(model)
  end

  defp render_assembled(assembled) do
    assembled
    |> Enum.map(fn %{__struct__: module} = model -> module.render(model) end)
    |> Enum.join(" ")
  end

  defp with_brackets(rendered) do
    "{\n" <> rendered <> "\n}"
  end

  def assemble(%__MODULE__{sequence: sequence}) do
    sequence
    |> Enum.reverse
    |> assemble
  end
  def assemble([]) do
    []
  end

  # roots
  def assemble([Mutation | _ ] = sequence) do
    assemble(sequence, %Mutation{})
  end
  def assemble([Schema | _ ] = sequence) do
    assemble(sequence, %Schema{})
  end

  # func with empty block followed by a filter
  def assemble([%Func{block: {}} = func, %Filter{} = filter | rest]) do
    [ func, filter | assemble(rest) ]
  end

  def assemble([anything | rest]) do
    [ anything | assemble(rest) ]
  end

  # mutation set
  def assemble([Mutation, MutationSet, %Field{} = field | rest], %Mutation{} = mutation) do
    assemble([Mutation, MutationSet | rest], Mutation.put_set(mutation, field))
  end
  # no more fields; done with MutationSet
  def assemble([Mutation, MutationSet | rest], %Mutation{} = mutation) do
    assemble([Mutation | rest], mutation)
  end
  
  # mutation schema
  def assemble([Mutation, Schema, %Field{} = field | rest], %Mutation{} = mutation) do
    # put field in mutation schema
    assemble([Mutation, Schema | rest], Mutation.put_schema(mutation, field))
  end
  def assemble([Mutation, Schema | rest], %Mutation{} = mutation) do
    # no more fields in mutation schema
    assemble([Mutation | rest], mutation)
  end
  def assemble([Mutation | rest ], %Mutation{} = mutation) do
    # done with mutation
    case List.flatten([mutation | assemble(rest)]) do
      [alone] -> alone
      x when length(x) > 1 -> x
    end
  end

  # naked schema
  def assemble([Schema, %Field{} = field | rest ], %Schema{} = schema) do
    # put field in naked schema
    assemble([Schema | rest], Schema.put_field(schema, field))
  end
  def assemble([Schema | rest ], %Schema{} = schema) do
    # done with naked schema
    case List.flatten([ schema | assemble(rest) ]) do
      [alone] -> alone
      x when length(x) > 1 -> x
    end
  end

end