defmodule HikkaBackup do
  use Application, restart: :temporary, significant: true

  defmodule Creds do
    alias HikkaBackup.S3Creds

    @enforce_keys [:token, :s3]
    defstruct [:token, :s3]

    @type t :: %__MODULE__{token: String.t(), s3: S3Creds.t()}
  end

  defmodule S3Creds do
    @enforce_keys [:key_id, :access_key]
    defstruct [:account_id, :key_id, :access_key, region: "auto", url: :r2]

    @type t :: %__MODULE__{
            account_id: String.t(),
            key_id: String.t(),
            access_key: String.t(),
            region: String.t(),
            url: :r2 | String.t()
          }
  end

  def start(_type, args) do
    Supervisor.start_link([{__MODULE__, [args]}],
      strategy: :one_for_one,
      auto_shutdown: :any_significant
    )
  end

  def start_link(opts) do
    Task.start_link(fn -> main(opts) end)
  end

  @spec main(any()) :: :ok
  def main(_args) do
    creds = %Creds{
      token: System.fetch_env!("TOKEN"),
      s3: %S3Creds{
        key_id: System.fetch_env!("S3_ACCESS_KEY_ID"),
        access_key: System.fetch_env!("S3_SECRET_ACCESS_KEY"),
        account_id: System.get_env("CLOUDFLARE_ACCOUNT_ID", nil),
        url: System.get_env("S3_URL") || :r2,
        region: System.get_env("S3_REGION", "auto")
      }
    }

    run(creds)
  end

  @spec run(Creds.t()) :: :ok
  def run(creds) when creds.token != "" do
    req =
      Req.new(base_url: "https://api.hikka.io/") |> Req.Request.put_header("auth", creds.token)

    %{status: 200, body: %{"username" => user}} = Req.get!(req, url: "/user/me")

    ts = DateTime.utc_now() |> DateTime.to_iso8601()

    IO.puts("Hello, #{user}! Backing up your data ...")

    [{:watch, &fetch_watch/2}, {:read, &fetch_read/2}]
    |> Task.async_stream(
      fn {tag, fetcher} ->
        fetcher.(req, user) |> Jason.encode!() |> upload_s3!("#{tag}-#{ts}.json", creds.s3)
      end,
      ordered: false,
      timeout: 30_000
    )
    |> Stream.run()

    # files
    # |> Enum.map(fn {path, content} -> File.write!(path, content) end)
    # |> Enum.map(&Task.async/1)

    :ok
  end

  @spec upload_s3!(String.t(), String.t(), S3Creds.t()) :: :ok
  defp upload_s3!(content, name, creds) do
    options = [
      access_key_id: creds.key_id,
      secret_access_key: creds.access_key,
      service: :s3,
      region: creds.region
    ]

    url =
      case creds.url do
        :r2 when creds.account_id != nil ->
          "https://#{creds.account_id}.r2.cloudflarestorage.com/backup"

        url when url != nil ->
          url
      end

    req = Req.new(base_url: url, aws_sigv4: options)

    IO.puts("Uploading #{name} of size #{byte_size(content)} bytes...")

    %{status: 200} =
      Req.put!(req,
        url: "/hikka/#{name}",
        body: content,
        headers: [content_length: byte_size(content), content_type: "application/json"]
      )

    :ok
  end

  @spec fetch_watch(Req.Request.t(), String.t()) :: [map()]
  defp fetch_watch(req, user) do
    collect_all_pages(Req.merge(req, url: "/watch/:user/list", path_params: [user: user]))
  end

  @spec fetch_read(Req.Request.t(), String.t()) :: [map()]
  defp fetch_read(req, user) do
    ["manga", "novel"]
    |> Enum.flat_map(fn type ->
      collect_all_pages(
        Req.merge(req,
          url: "/read/:content_type/:user/list",
          path_params: [user: user, content_type: type]
        )
      )
    end)
  end

  @spec collect_all_pages(Req.Request.t()) :: [map()]
  defp collect_all_pages(req) do
    IO.puts(
      "Processing #{req.url |> URI.to_string()} with path params #{inspect(req.options.path_params)}..."
    )

    req = Req.merge(req, params: [size: 100], body: "{}")

    %{"pagination" => %{"pages" => pages, "total" => total}, "list" => head} = fetch_page(req, 1)

    IO.puts("Found #{pages} pages, containing #{total} entries")

    rest =
      2..pages//1
      |> Task.async_stream(fn page -> fetch_page(req, page) |> Map.fetch!("list") end,
        max_concurrency: 4,
        ordered: false,
        timeout: 15_000
      )
      |> Enum.map(fn {:ok, list} -> list end)

    [head | rest]
  end

  defp fetch_page(req, page) do
    IO.puts("Fetching #{page} page...")
    %{status: 200, body: body} = Req.post!(req, params: [page: page])
    body
  end
end
