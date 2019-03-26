use Mix.Config

# Configure the main viewport for the Scenic application
config :scenic_scrollable, :viewport, %{
  name: :main_viewport,
  size: {700, 600},
  default_scene: {Scenic.Scrollable.TestParentScene, nil},
  drivers: [
    %{
      module: Scenic.Driver.Glfw,
      name: :glfw,
      opts: [resizeable: false, title: "scenic_scrollable"]
    }
  ]
}
