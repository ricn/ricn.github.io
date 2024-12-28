import Config

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.24.2",
  default: [
    args:
      ~w(app.js --bundle --target=es2017 --outdir=../docs/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.17",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=../assets/app.css
      --output=../docs/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]
