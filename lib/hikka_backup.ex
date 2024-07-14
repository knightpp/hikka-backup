defmodule HikkaBackup do
  def main(_args) do
    token = System.fetch_env!("TOKEN")
    run(token)
  end

  def run(token) when token != "" do
    req = Req.new(base_url: "https://api.hikka.io/") |> Req.Request.put_header("auth", token)
    %{status: 200, body: %{"username" => user}} = Req.get!(req, url: "/user/me")

    IO.puts("Hello, #{user}! Backing up your data ...")

    anime = fetch_watch(req, user) |> Jason.encode!()
    manga = fetch_read(req, user) |> Jason.encode!()

    ts = DateTime.utc_now() |> DateTime.to_iso8601()

    File.write!("anime-#{ts}.json", anime)
    File.write!("manga-#{ts}.json", manga)
  end

  # defp fetch_all(req, user) do
  #   [fetch_read, fetch_watch] |> Enum.flat_map(fn x -> 
  #     x.(req, user)
  #   end)
  # end

  defp fetch_watch(req, user) do
    collect_all_pages(Req.merge(req, url: "/watch/:user/list", path_params: [user: user]))
  end

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
    IO.puts("Processing #{req.url |> URI.to_string()}...")

    req = Req.merge(req, params: [size: 100], body: "{}")

    %{status: 200, body: body} = Req.post!(req)

    pages = body["pagination"]["pages"]
    IO.puts("Found #{pages} pages, containing #{body["pagination"]["total"]} entries")

    rest =
      Enum.map(2..pages//1, fn page ->
        IO.puts("Fetching #{page} page...")
        %{status: 200, body: body} = Req.post!(req, params: [page: page])
        body["list"]
      end)

    [body["list"] | rest]
  end
end
