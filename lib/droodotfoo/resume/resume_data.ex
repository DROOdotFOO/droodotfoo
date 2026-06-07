defmodule Droodotfoo.Resume.ResumeData do
  @moduledoc """
  Resume data structure and content management.

  ## Single Source of Truth

  **`priv/resume.json` is the authoritative source** for all resume data. This JSON file
  is included in the application release and should always be available in production.

  ## Loading Resume Data

  The module loads resume data in this priority order:

  1. **Primary source**: `priv/resume.json` (always used in production)
  2. **Fallback**: Hardcoded data (primarily for testing when JSON unavailable)

  ### Data Consistency

  The hardcoded fallback data in `get_hardcoded_resume_data/0` is kept in sync with
  `priv/resume.json` to ensure test compatibility. When updating resume data:

  1. Update `priv/resume.json` (the authoritative source)
  2. Update hardcoded data in this module (for test compatibility)
  3. Verify both sources match

  ### Production Usage

  In production, the application always loads from `priv/resume.json`. The hardcoded
  fallback exists primarily for testing scenarios where the file system may not be
  fully initialized.
  """

  require Logger

  defstruct [
    :personal_info,
    :summary,
    :availability,
    :focus_areas,
    :experience,
    :education,
    :defense_projects,
    :upstream_contributions,
    :portfolio,
    :certifications,
    :contact
  ]

  @type t :: %__MODULE__{
          personal_info: map(),
          summary: String.t(),
          availability: String.t(),
          focus_areas: list(String.t()),
          experience: list(map()),
          education: list(map()),
          defense_projects: list(map()),
          upstream_contributions: list(map()),
          portfolio: map(),
          certifications: list(map()),
          contact: map()
        }

  @cache_key {__MODULE__, :resume_data}

  @doc """
  Gets resume data, checking sources in order:
  1. Cache (persistent_term for fast access)
  2. Local file at priv/resume.json (if exists)
  3. Hardcoded fallback data

  Returns a map (not struct) for compatibility with existing code.
  """
  def get_resume_data do
    case :persistent_term.get(@cache_key, nil) do
      nil ->
        # Cache miss - load and cache
        data = load_and_cache_resume()
        data

      cached_data ->
        # Cache hit
        cached_data
    end
  end

  @doc """
  Clears the cached resume data and reloads from source.
  Useful when resume data has been updated.
  """
  def refresh_resume_data do
    :persistent_term.erase(@cache_key)
    load_and_cache_resume()
  end

  # Private function to load resume data and store in cache
  defp load_and_cache_resume do
    data =
      case load_from_local_file() do
        {:ok, data} ->
          Logger.info("Loaded resume from local file (priv/resume.json)")
          data

        {:error, _local_reason} ->
          Logger.debug("Using hardcoded resume data (no local file available)")
          get_hardcoded_resume_data()
      end

    :persistent_term.put(@cache_key, data)
    data
  end

  @doc """
  Loads resume data from local file at priv/resume.json.
  """
  def load_from_local_file do
    resume_path = Application.app_dir(:droodotfoo, "priv/resume.json")

    case File.read(resume_path) do
      {:ok, json_content} ->
        case Jason.decode(json_content, keys: :atoms) do
          {:ok, data} ->
            {:ok, data}

          {:error, reason} ->
            Logger.error("Failed to decode JSON from #{resume_path}: #{inspect(reason)}")
            {:error, :json_decode_error}
        end

      {:error, reason} ->
        Logger.debug("Could not read local resume file at #{resume_path}: #{inspect(reason)}")
        {:error, :file_not_found}
    end
  end

  @doc """
  Gets the hardcoded resume data (fallback for testing).

  This data is kept in sync with `priv/resume.json` to ensure test compatibility.
  It serves as a fallback when the JSON file is unavailable, primarily during testing.

  **Note**: This is not the primary data source. Always update `priv/resume.json` first,
  then sync changes here for test compatibility.
  """
  def get_hardcoded_resume_data do
    %__MODULE__{
      personal_info: %{
        name: "DROO AMOR",
        title: "Blockchain Infrastructure Engineer",
        location: "Remote",
        timezone: "Europe/Madrid",
        website: "https://droo.foo",
        languages: %{
          english: "native",
          spanish: "learning",
          german: "learning",
          russian: "learning",
          catalan: "learning"
        }
      },
      summary:
        "Building blockchain infrastructure (mana Ethereum client, raxol terminal framework) for Cosmos and Ethereum. Previously: nuclear submarine engineering where bugs had operational consequences, competitive intelligence at LidoDAO. Preference for systems where correctness matters more than speed.",
      availability: "open_to_consulting",
      focus_areas: ["Ethereum Protocol", "Zero-Knowledge Circuits", "Validator Infrastructure"],
      experience: [
        %{
          company: "xochi.fi",
          position: "BDFL / Protocol Director",
          location: "Remote",
          employment_type: "full-time",
          start_date: "2026-04",
          end_date: "Present",
          description:
            "Dark pool DEX solving the compliance-privacy problem on Ethereum. Intent-based trading settled into stealth accounts or Aztec shielded notes across five chains. ZKP compliance oracle proves AML/sanctions compliance without revealing transaction data.",
          achievements: [
            "Co-authored ERC-8262 (Zero-Knowledge Compliance Oracle) with six proof types in Noir, now on the Ethereum standards track",
            "Built Riddler, a cross-chain intent solver with <6s latency across Ethereum, Optimism, Base, Arbitrum, and Polygon",
            "Architected privacy tier system combining trust scores with stealth addresses (ERC-5564) and account abstraction (ERC-4337)"
          ],
          technologies: %{
            languages: ["Noir", "Solidity", "TypeScript", "Rust"],
            protocols: ["ERC-5564", "ERC-4337", "Aztec"],
            tools: ["Foundry", "Barretenberg", "UltraHonk"]
          }
        },
        %{
          company: "axol.io",
          position: "CEO",
          location: "Remote",
          employment_type: "full-time",
          start_date: "2024-05",
          end_date: "Present",
          description:
            "Open-source blockchain infrastructure company supporting xochi.fi. Building production-grade FOSS tooling for staking, Ethereum clients, and terminal frameworks.",
          achievements: [
            "Founded axol.io, developing mana Ethereum client and raxol terminal UI framework as production-grade FOSS tools",
            "Built and maintain open-source blockchain infrastructure community with active contributor base"
          ],
          technologies: %{
            languages: ["Elixir", "Python", "Rust", "Nix"],
            "internal-products": [
              "Sequencer",
              "MEV Searcher",
              "Builder",
              "Solvers",
              "Validators",
              "RPCs",
              "APIs"
            ],
            tools: ["Ansible", "Terraform"]
          }
        },
        %{
          company: "LidoDAO",
          position: "NOM Protocol Specialist",
          location: "Remote",
          employment_type: "contract",
          start_date: "2023-03",
          end_date: "2024-05",
          description:
            "Led Node Operations Mechanisms (NOM) strategy for LidoDAO, the largest liquid staking protocol ($34B TVL). Led competitive intelligence and ecosystem research, delivering strategic analyses to DAO leadership.",
          achievements: [
            "Delivered 60+ weekly Competition & Ecosystem Landscape reports providing strategic insights to inform product decisions",
            "Built competitive intelligence tool, beachpatrol, for monitoring competitor protocols using OSINT methodologies",
            "Analyzed node operator economics and performance metrics across multiple blockchain networks"
          ],
          technologies: %{
            languages: ["Python"],
            methodologies: ["OSINT"]
          }
        },
        %{
          company: "Blockdaemon",
          position: "R&D Protocol Research Specialist",
          location: "Remote",
          employment_type: "full-time",
          start_date: "2022-01",
          end_date: "2023-03",
          description:
            "Technical evaluation and integration of blockchain protocol prototypes for venture investment, product development, and node infrastructure deployment.",
          achievements: [
            "Created governance framework and implemented voting system using Cosmos SDK authz module with Go, Ansible, and Bash scripting",
            "Conducted code analysis and prototype deployment to evaluate blockchain project software infrastructure requirements"
          ],
          technologies: %{
            languages: ["JavaScript", "Rust", "Julia", "Zig"],
            frameworks: ["Cosmos SDK"],
            tools: ["Ansible", "Terraform", "Docker", "Grafana", "Prometheus"]
          }
        },
        %{
          company: "General Dynamics Electric Boat",
          position: "Mechanical & Electrical Test Engineer",
          location: "Groton, CT",
          employment_type: "full-time",
          start_date: "2020-10",
          end_date: "2022-01",
          description:
            "Engineering Lead of JTG HM&E Engineering for $9B+ of nuclear submarine PSA projects.",
          achievements: [
            "Accelerated engineering deliverables by 11% vs previous PSA projects through systematic troubleshooting and cross-functional consultation",
            "Led Program Management & QA of underway Sea Trials for testing and certification process, meeting stringent customer and contractual requirements",
            "Managed high-risk re-entry controls, roadmap and product liability tracking for PSA & NEWCON nuclear submarines"
          ],
          technologies: %{
            languages: ["MATLAB"],
            tools: [
              "Git",
              "MRPII",
              "ELCADD",
              "LabView",
              "AutoCAD",
              "Figma",
              "Teamcenter",
              "Trello"
            ]
          }
        },
        %{
          company: "General Dynamics Electric Boat",
          position: "R&D Engineer",
          location: "Groton, CT",
          employment_type: "full-time",
          start_date: "2018-12",
          end_date: "2020-11",
          description:
            "Technical Lead for cross-department rapid prototyping inventions (Mech/Elec), managing 5-10 person teams with budgeting up to $15M monthly per project for US warfare components.",
          achievements: [
            "Developed calibration and repair process for precision instruments, eliminating $20M in replacement costs",
            "Invented mechanical/electrical system reducing submarine tactical weapon launch cycle by 14% (timing details classified)",
            "Designed specialized tooling and procedures reducing personnel exposure in radioactive zones by 34%"
          ],
          technologies: %{
            languages: ["MATLAB"],
            tools: [
              "Git",
              "MRPII",
              "ELCADD",
              "LabView",
              "AutoCAD",
              "Figma",
              "Teamcenter",
              "Trello"
            ]
          }
        },
        %{
          company: "General Dynamics Electric Boat",
          position: "Shipyard Test Organization Specialist",
          location: "Groton, CT",
          employment_type: "full-time",
          start_date: "2017-06",
          end_date: "2018-12",
          description:
            "Field engineering and troubleshooting of mechanical and electrical submarine systems, material strength, and operation.",
          achievements: [
            "Performed QA/QC for classified, NOFORN, DSS-SOC, and SUBSAFE systems",
            "Led operational programs and maintained relationships between US Navy customer, private vendors, and shipyard personnel",
            "Conducted hydrostatic tests, Lockout/Tag-out, shipboard troubleshooting, high-risk operations, and material strength tests"
          ],
          technologies: %{
            methodologies: [
              "Quality Assurance",
              "Quality Control",
              "Hydrostatic Testing",
              "Lockout/Tag-out",
              "SUBSAFE",
              "Material Testing",
              "Hydraulics",
              "HVAC"
            ]
          }
        }
      ],
      education: [
        %{
          institution: "SUNY Maritime College",
          degree: "Bachelor of Science",
          field: "Marine Operations",
          concentration: "Engineering",
          start_date: "2013-09",
          end_date: "2017-05",
          location: "Bronx, NYC",
          minor: "Pre-law & Management",
          achievements: %{
            leadership: [
              "SGA & Student Body Vice President 2013",
              "SGA & Student Body Secretary 2012"
            ],
            academic: [
              "Licensed USCG Deck Officer, Third Mates Unlimited Tonnage Program",
              "Tutor & Coach for all Navigation and Seamanship classes during tenure"
            ],
            athletics: [
              "All-American Skipper/Crew for Competitive Dinghy and Offshore Sailing"
            ]
          }
        }
      ],
      upstream_contributions: [
        %{
          project: "FFmpeg",
          title: "aarch64 NEON optimizations for swscale and libavfilter",
          description:
            "ARM NEON assembly for swscale YUV->RGB conversion: 16-bit packed paths plus the 2-line row-pair series co-authored with Ramiro Polla. libavfilter vf_threshold queued. 10 commits on master.",
          url: "https://code.ffmpeg.org/DROOdotFOO?tab=activity",
          type: "merged",
          date: "2026-06",
          tags: ["C", "aarch64", "NEON", "SIMD", "swscale", "libavfilter"]
        },
        %{
          project: "Ethereum ERCs",
          title: "ERC-8262: Zero-Knowledge Compliance Oracle (co-author)",
          description:
            "Six proof types in Noir circuits with multi-jurisdiction policy framework. Draft status on the Ethereum standards track.",
          url: "https://github.com/ethereum/ERCs/pull/1747",
          type: "standard",
          date: "2026-04",
          tags: ["Noir", "Solidity", "ZK", "EIP"]
        },
        %{
          project: "Dappnode",
          title: "Charon health check fix (Obol DVT package)",
          description: "Fixed Charon health probe in Dappnode's Obol DVT generic package.",
          url: "https://github.com/dappnode/DAppNodePackage-obol-generic/pull/90",
          type: "merged",
          date: "2026-01",
          tags: ["Obol", "DVT", "Charon"]
        },
        %{
          project: "Dappnode",
          title: "Avado migration guide",
          description: "Migration documentation from Avado to Dappnode.",
          url: "https://github.com/dappnode/DAppNodeDocs/pull/423",
          type: "docs",
          date: "2024-08",
          tags: ["docs", "Dappnode"]
        },
        %{
          project: "Zed",
          title: "aztec-noir language extension",
          description:
            "Noir LSP and tree-sitter syntax for Aztec contracts, published to the Zed marketplace.",
          url: "https://github.com/zed-industries/extensions/tree/main/extensions/aztec-noir",
          type: "extension",
          date: "2026-05",
          tags: ["Zed", "Noir", "Aztec"]
        },
        %{
          project: "Zed",
          title: "synthwave84 theme",
          description: "Synthwave84 theme published to the Zed marketplace.",
          url: "https://github.com/zed-industries/extensions/tree/main/extensions/synthwave84",
          type: "extension",
          date: "2025-07",
          tags: ["Zed", "theme"]
        }
      ],
      defense_projects: [
        %{
          name: "Nuclear Submarine Tactical R&D Systems",
          description:
            "Invented mechanical/electrical system reducing submarine tactical weapon launch cycle by 14% (timing details classified). Designed specialized tooling and procedures reducing personnel exposure in radioactive zones by 34% across Columbia and Virginia-class submarine programs.",
          technologies: %{
            domains: ["Mechanical Engineering", "Electrical Engineering"],
            systems: ["Nuclear Systems", "Precision Manufacturing"]
          },
          url: "Classified",
          status: "Completed",
          role: "Technical Lead",
          start_date: "2018-12",
          end_date: "2020-11"
        },
        %{
          name: "Precision Instrument Calibration System",
          description:
            "Developed comprehensive calibration and repair protocols for submarine precision instruments, eliminating $20M in anticipated replacement costs. Standardized maintenance procedures across test equipment inventory, extending service life while maintaining classification-level accuracy requirements.",
          technologies: %{
            methodologies: ["Precision Calibration", "Maintenance Protocols", "Quality Control"],
            impact: ["Cost Optimization"]
          },
          url: "Proprietary",
          status: "Completed",
          role: "R&D Engineer",
          start_date: "2019-01",
          end_date: "2020-11"
        }
      ],
      portfolio: %{
        organization: %{
          name: "axol.io",
          url: "https://github.com/axol-io",
          description: "Open source blockchain infrastructure and tooling"
        },
        projects: [
          %{
            name: "mana",
            url: "https://github.com/axol-io/mana",
            description: "Ethereum protocol implementation in Elixir",
            language: "Elixir",
            status: "active",
            topics: ["blockchain", "elixir", "ethereum", "evm", "protocol", "web3"],
            highlights: [
              "Built on the BEAM VM: inherent concurrency, fault tolerance, and hot code reloading",
              "Functional architecture: immutable state, pattern matching, and pipeline-driven data flow",
              "Production-grade OTP: supervisors, GenServers, and distributed systems primitives",
              "Memory efficient: significantly lower resource consumption than Geth or Erigon",
              "Developer-friendly: readable codebase with clear separation of concerns"
            ]
          },
          %{
            name: "raxol",
            url: "https://github.com/DROOdotFOO/raxol",
            description: "Terminal UI framework for Elixir applications",
            language: "Elixir",
            status: "active",
            topics: [
              "ansi",
              "component-based",
              "elixir",
              "phoenix-liveview",
              "terminal-ui",
              "tui"
            ],
            highlights: [
              "Component-based architecture with declarative markup",
              "Real-time updates via Phoenix LiveView integration",
              "ANSI escape sequences for rich terminal rendering",
              "Event handling system for keyboard and mouse interactions",
              "Character-perfect grid alignment for monospace displays"
            ]
          },
          %{
            name: "riddler",
            url: "https://github.com/axol-io/riddler",
            description: "Cross-chain solver with automated rebalancing system",
            language: "Elixir",
            status: "active",
            private: true,
            topics: ["blockchain", "cross-chain", "defi", "elixir", "solver", "web3"],
            highlights: [
              "Across Protocol integration: multi-chain liquidity optimization",
              "Wormhole support in development: Solana and Sui bridge connectivity",
              "Automated rebalancing algorithms for cross-chain inventory management",
              "Real-time monitoring and execution of profitable solver opportunities"
            ]
          }
        ]
      },
      certifications: [
        %{
          name: "Secret Security Clearance",
          issuer: "United States Government",
          date: "Active",
          credential_id: "SECRET-CLEARANCE"
        },
        %{
          name: "Steam & Electric Plant S9G Reactor Qualified",
          issuer: "US Navy Nuclear Program",
          date: "Active",
          credential_id: "S9G-REACTOR-QUALIFIED"
        },
        %{
          name: "USCG Third Mate Unlimited Tonnage License",
          issuer: "United States Coast Guard",
          date: "Inactive",
          credential_id: "USCG-3RD-MATE-UNLIMITED"
        }
      ],
      contact: %{
        email: "drew@axol.io",
        website: "https://droo.foo",
        github: "https://github.com/DROOdotFOO",
        linkedin: "https://linkedin.com/in/droodotfoo",
        twitter: "https://x.com/DROOdotFOO"
      }
    }
    |> struct_to_map()
  end

  # Convert struct to plain map for compatibility
  defp struct_to_map(%__MODULE__{} = struct) do
    Map.from_struct(struct)
  end

  def get_resume_formats do
    [
      %{
        id: "technical",
        name: "Technical Resume",
        description: "Developer-focused format with emphasis on technical skills and projects"
      },
      %{
        id: "executive",
        name: "Executive Summary",
        description: "High-level overview suitable for leadership positions"
      },
      %{
        id: "minimal",
        name: "Minimal Resume",
        description: "Clean, concise format for quick scanning"
      },
      %{
        id: "detailed",
        name: "Detailed Resume",
        description: "Comprehensive format with full project descriptions"
      }
    ]
  end
end
