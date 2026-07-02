defmodule DroodotfooWeb.NowLive do
  @moduledoc """
  Now page showing current focus and activities.
  Inspired by Derek Sivers' /now page movement (nownownow.com).
  Updated manually to reflect current status.
  """

  use DroodotfooWeb, :live_view
  use DroodotfooWeb.ContributionHelpers
  alias Droodotfoo.Resume.ResumeData
  import DroodotfooWeb.ContentComponents
  import DroodotfooWeb.GithubComponents

  @impl true
  def mount(_params, _session, socket) do
    resume = ResumeData.get_resume_data()
    last_updated = Droodotfoo.Core.Config.released_on()

    if connected?(socket), do: DroodotfooWeb.ContributionHelpers.init_contributions()

    socket =
      socket
      |> assign(:resume, resume)
      |> assign(:last_updated, last_updated)
      |> assign_page_meta("Now", "/now", breadcrumb_json_ld("Now", "/now"))
      |> assign(DroodotfooWeb.ContributionHelpers.contribution_assigns())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_layout
      page_title="Now"
      page_description="What I'm currently focused on"
      current_path={@current_path}
    >
      <section class="about-section">
        <.contribution_graph
          id="now-contributions"
          grid={@contribution_grid}
          loading={@contributions_loading}
        />

        <hr />

        <div class="text-muted mb-2">
          <strong>Last updated:</strong>
          {Date.to_string(@last_updated)}
        </div>

        <h2 class="section-title">Running</h2>
        <p>
          <.ext_link href="https://xochi.fi" text="xochi.fi" />
          : private exchange & friendly dark pool on Ethereum. ZK compliance via
          <.ext_link
            href="https://ethereum-magicians.org/t/erc-8262-zero-knowledge-compliance-oracle/28543"
            text="ERC-8262"
          />, the Zero-Knowledge Compliance Oracle standard we co-authored.
          <.ext_link href="https://axol.io" text="axol.io" />
          runs the infra. Raising. The open infrastructure side is funded through
          <.ext_link href="https://giveth.io/project/axolio-xochifi" text="Giveth" />.
        </p>

        <article class="experience-item">
          <div class="experience-header">
            <div class="experience-title">Riddler</div>
          </div>
          <p class="experience-description">
            Intent solver, ~2s fills across five chains. P95 under 6s.
            <.ext_link
              href="https://github.com/lifinance/riddler-solver-client"
              text="LI.FI integrated it"
            /> as a solver client. Also on Across, Everclear, soon Wormhole and COWswap.
          </p>

          <.tech_tags technologies={["Ethereum", "Optimism", "Base", "Arbitrum", "Polygon"]} />
        </article>

        <article class="experience-item">
          <div class="experience-header">
            <div class="experience-title">axol.io infra</div>
            <div class="experience-company">Production</div>
          </div>

          <p class="experience-description">
            Aztec sequencer, Ethereum validators, MEV searcher
            via Sphinx.
          </p>

          <.tech_tags technologies={["Aztec", "Ethereum", "Sphinx"]} />
        </article>

        <article class="experience-item">
          <div class="experience-header">
            <div class="experience-title">Raxol</div>
            <div class="experience-company">Live on Virtuals</div>
          </div>

          <p class="experience-description">
            OTP-native agent runtime. A Raxol agent is live on
            <.ext_link href="https://app.virtuals.io" text="Virtuals" />: it owns its
            wallet, moves under a signed mandate, and settles privately through Xochi,
            the agentic dark pool.
          </p>

          <.tech_tags technologies={["Elixir", "OTP", "x402"]} />
        </article>

        <hr />

        <h2 class="section-title">Learning</h2>

        <details class="experience-details" open>
          <summary class="experience-summary">Current reading list</summary>
          <div class="mt-1">
            <ul>
              <li>
                MEV/HFT: searcher strategies, arb, liquidations,
                backrunning, latency
              </li>
              <li>
                Quant: solver rebalancing, cross-chain inventory,
                execution optimization
              </li>
              <li>
                Prediction markets: applying the quant work to
                Polymarket
              </li>
              <li>
                ZK compliance: ZKSAR proofs, sanctions screening,
                provider weight tuning
              </li>
              <li>
                OTP internals: gen_server, supervisor restarts,
                distributed Erlang
              </li>
            </ul>
          </div>
        </details>

        <hr />

        <h2 class="section-title">Location</h2>
        <p>
          {@resume.personal_info.location} ({@resume.personal_info.timezone}). Remote.
        </p>

        <p :if={@resume.availability == "open_to_consulting"} class="mt-1 text-muted">
          Open to consulting. Ethereum protocol, ZK circuits, validator infra. <.link navigate={
            ~p"/about"
          }>Background</.link>.
        </p>

        <hr />

        <p class="text-muted">
          This is a <.ext_link href="https://nownownow.com/about" text="/now page" />.
        </p>
      </section>
    </.page_layout>
    """
  end
end
