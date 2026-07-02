defmodule Droodotfoo.Content.PatternAnimations.CleanAir do
  @moduledoc false

  @spec css :: String.t()
  def css do
    """
    <style>
      @keyframes ca-wind-flow {
        from { stroke-dashoffset: 0; }
        to   { stroke-dashoffset: -28; }
      }
      .ca-wind {
        animation: ca-wind-flow 2.8s linear infinite;
        animation-delay: calc(var(--i, 0) * 0.12s);
      }
      @keyframes ca-mark-pulse {
        0%, 100% { opacity: 0.4; }
        50%      { opacity: 0.6; }
      }
      .ca-mark {
        animation: ca-mark-pulse 6s ease-in-out infinite;
      }
      @keyframes ca-line-breath {
        0%, 100% { opacity: 0.82; }
        50%      { opacity: 1; }
      }
      .ca-line {
        animation: ca-line-breath 5s ease-in-out infinite;
      }
      @keyframes ca-gust {
        0%, 100% { opacity: var(--op, 0.3); }
        50%      { opacity: calc(var(--op, 0.3) * 2.0); }
      }
      .ca-gust {
        animation: ca-gust 3.2s ease-in-out infinite;
        animation-delay: calc(var(--seg, 0) * -3.2s + var(--i, 0) * -0.55s);
      }
    </style>
    """
  end
end
