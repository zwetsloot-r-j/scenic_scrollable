defmodule ScenicScrollable.Scene.Home do
  use Scenic.Scene

  alias Scenic.Graph
  alias Scenic.Primitive.Style.Theme
  import Scenic.Scrollable.Components, only: [scrollable: 4]
  import Scenic.Components, only: [button: 3]

  import Scenic.Primitives
  # import Scenic.Components

  @note """
  Ecto.Schema View Source
  Defines a schema.

  An Ecto schema is used to map any data source into an Elixir struct. The definition of the schema is possible through two main APIs: schema/2 and embedded_schema/1.

  schema/2 is typically used to map data from a persisted source, usually a database table, into Elixir structs and vice-versa. For this reason, the first argument of schema/2 is the source (table) name. Structs defined with schema/2 also contain a __meta__ field with metadata holding the status of the struct, for example, if it has been built, loaded or deleted.

  On the other hand, embedded_schema/1 is used for defining schemas that are embedded in other schemas or only exist in-memory. For example, you can use such schemas to receive data from a command line interface and validate it, without ever persisting it elsewhere. Such structs do not contain a __meta__ field, as they are never persisted.

  Besides working as data mappers, embedded_schema/1 and schema/2 can also be used together to decouple how the data is represented in your applications from the database. Let’s see some examples.

   Example
  defmodule User do
    use Ecto.Schema

    schema "users" do
      field :name, :string
      field :age, :integer, default: 0
      has_many :posts, Post
    end
  end
  By default, a schema will automatically generate a primary key which is named id and of type :integer. The field macro defines a field in the schema with given name and type. has_many associates many posts with the user schema. Schemas are regular structs and can be created and manipulated directly using Elixir’s struct API:

  user = %User{name: "jane"}
  %{user | age: 30}
  However, most commonly, structs are cast, validated and manipulated with the Ecto.Changeset module.

  Note that the name of the database table does not need to correlate to your module name. For example, if you are working with a legacy database, you can reference the table name when you define your schema:

  defmodule User do
    use Ecto.Schema

    schema "legacy_users" do
      # ... fields ...
    end
  end
  Embedded schemas are defined similarly to source-based schemas. For example, you can use an embedded schema to represent your UI, mapping and validating its inputs, and then you convert such embedded schema to other schemas that are persisted to the database:

  defmodule SignUp do
    use Ecto.Schema

    embedded_schema do
      field :name, :string
      field :age, :integer
      field :email, :string
      field :accepts_conditions, :boolean
    end
  end

  defmodule Profile do
    use Ecto.Schema

    schema "profiles" do
      field :name
      field :age
      belongs_to :account, Account
    end
  end

  defmodule Account do
    use Ecto.Schema

    schema "accounts" do
      field :email
    end
  end
  The SignUp schema can be cast and validated with the help of the Ecto.Changeset module, and afterwards, you can copy its data to the Profile and Account structs that will be persisted to the database with the help of Ecto.Repo.
  """

  @graph Graph.build(font: :roboto, font_size: 24)
         |> text(@note, translate: {20, 60})

  # ============================================================================
  # setup

  # --------------------------------------------------------
  def init(_, _) do
    Graph.build(font: :roboto, font_size: 24)
    |> scrollable(
      %{frame: {500, 500}, content: %{x: 0, y: 15, width: 1200, height: 2200}},
      fn graph ->
        text(graph, @note)
        |> button("ok", translate: {25, 2000})
#        |> rect({150, 100}, translate: {25, 50}, fill: :red)
      end,
      translate: {10, 10},
      scroll_position: {0, 0},
      scroll_hotkeys: %{up: "w", down: "s", left: "d", right: "a"},
      scroll_drag: %{mouse_buttons: [:left]},
      vertical_scroll_bar: [scroll_buttons: true, scroll_bar_theme: Theme.preset(:light)],
      horizontal_scroll_bar: [scroll_buttons: false, scroll_bar_theme: Theme.preset(:danger)]
    )
    #    |> group(fn graph ->
    #      graph
    #      |> text(@note, translate: {0, 15})
    #    end, scissor: {200, 200}, translate: {100, 100})
    |> push_graph()
    |> ResultEx.return()
  end
end
