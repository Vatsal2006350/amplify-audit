"""
amplify-audit/scoring.jac — Information-theoretic scoring algorithms.

Implements the composite SKU health scoring model:
  S(p) = w_r * R(p) + w_t * T(p) + w_k * K(p) + w_c * C(p)

Where:
  R(p) = return rate signal
  T(p) = ticket rate signal
  K(p) = keyword signal density
  C(p) = 1 - H_norm(p), reason concentration via Shannon entropy

All functions are pure (no side effects, no external dependencies).
"""

import from math { log2 }

# ─── Weight Configuration ────────────────────────────────────────────────────

glob WEIGHT_RETURN_RATE: int = 40;
glob WEIGHT_TICKET_RATE: int = 20;
glob WEIGHT_KEYWORD_SIGNALS: int = 25;
glob WEIGHT_REASON_CONCENTRATION: int = 15;

# ─── Core Scoring Functions ──────────────────────────────────────────────────

def compute_return_rate(return_count: int, order_count: int) -> float {
    """Compute return rate as a ratio."""
    if order_count == 0 {
        return 0.0;
    }
    return return_count / order_count;
}

def compute_ticket_rate(ticket_count: int, order_count: int) -> float {
    """Compute support ticket rate as a ratio."""
    if order_count == 0 {
        return 0.0;
    }
    return ticket_count / order_count;
}

def compute_reason_concentration(breakdown: dict) -> float {
    """
    Shannon entropy of reason distribution, inverted.

    Lower entropy = more concentrated reasons = clearer signal.
    Returns 0.0 (uniform distribution) to 1.0 (single reason).

    Formally:
      H(X) = -sum(p_i * log2(p_i)) for each unique reason i
      H_norm = H(X) / log2(|reasons|)
      C(p) = 1 - H_norm
    """
    values = list(breakdown.values());
    total = sum(values);
    if total == 0 {
        return 0.0;
    }

    n = len(values);
    if n <= 1 {
        return 1.0;
    }

    probs = [v / total for v in values];
    max_entropy = log2(n);
    if max_entropy == 0 {
        return 1.0;
    }

    entropy = 0.0;
    for p in probs {
        if p > 0 {
            entropy -= p * log2(p);
        }
    }

    normalized = entropy / max_entropy;
    return 1.0 - normalized;
}

def compute_fixability_score(
    return_rate: float,
    ticket_rate: float,
    keyword_signal_count: int,
    reason_breakdown: dict
) -> float {
    """
    Composite fixability score S(p) in [0, 100].

    Higher = more likely a PDP fix will reduce returns.

    S(p) = (w_r * min(R*100, 100) + w_t * min(T*100, 100)
          + w_k * min(K*10, 100) + w_c * C*100) / 100

    Where w_r=40, w_t=20, w_k=25, w_c=15.
    """
    return_rate_score = min(return_rate * 100, 100.0);
    ticket_rate_score = min(ticket_rate * 100, 100.0);
    keyword_score = min(keyword_signal_count * 10, 100);
    concentration_score = compute_reason_concentration(reason_breakdown) * 100;

    composite = (
        return_rate_score * WEIGHT_RETURN_RATE
        + ticket_rate_score * WEIGHT_TICKET_RATE
        + keyword_score * WEIGHT_KEYWORD_SIGNALS
        + concentration_score * WEIGHT_REASON_CONCENTRATION
    ) / 100.0;

    return round(composite * 100) / 100;
}

def compute_confidence(order_count: int, return_count: int) -> float {
    """
    Statistical confidence based on sample size.

    Uses a step function with linear interpolation:
      orders < 10  -> 0.2
      orders < 30  -> 0.4
      orders < 50  -> 0.6
      returns < 5  -> 0.5
      otherwise    -> 0.7 + min(orders/200, 0.2), capped at 0.95
    """
    if order_count < 10 {
        return 0.2;
    }
    if order_count < 30 {
        return 0.4;
    }
    if order_count < 50 {
        return 0.6;
    }
    if return_count < 5 {
        return 0.5;
    }

    sample_bonus = min(order_count / 200.0, 0.2);
    return min(0.7 + sample_bonus, 0.95);
}

def compute_quality_score(error_count: int, warning_count: int, info_count: int) -> int {
    """
    Rule-based quality score Q(p) in [0, 100].

    Q(p) = max(0, min(100, 100 - 20*E - 10*W - 3*I))

    Where E = error count, W = warning count, I = info count.
    """
    score = 100 - error_count * 20 - warning_count * 10 - info_count * 3;
    return max(0, min(100, score));
}
