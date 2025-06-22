using Random, Agents

# ---------- transmission (one-step von-Neumann) ----------
function disease_transmission!(model)
  for a in allagents(model)
    for nbr in nearby_agents(a, model, 1)
      isempty(nbr.diseases) && continue
      d = rand(abmrng(model), nbr.diseases)
      if all(!isequal(d, x) for x in a.diseases)
        push!(a.diseases, deepcopy(d))
      end
    end
  end
end

# ---------- immune response & sugar penalty ----------
function immune_response!(model)
  for a in allagents(model)
    new_immunity = _apply_diseases(a.immunity, a.diseases)
    lacking = count(d -> !_subseq(d, new_immunity), a.diseases)
    a.immunity = new_immunity
    a.sugar -= lacking       # metabolism penalty
  end
end

# ----- helpers -----
# Determine whether bit-vector `d` occurs as a contiguous subsequence of `I`
# without constructing intermediate ranges that depend on `length` for
# indexing. The implementation respects arbitrary array indices.
function _subseq(d::BitVector, I::BitVector)
  start_idx = firstindex(I)
  last_idx = lastindex(I) - length(d) + 1
  for i in start_idx:last_idx
    @inbounds begin
      match = true
      for j in eachindex(d)
        if I[i+j-1] != d[j]
          match = false
          break
        end
      end
      match && return true
    end
  end
  return false
end

function _hamming(a::AbstractVector{Bool}, b::AbstractVector{Bool})
  sum(x != y for (x, y) in zip(a, b))
end

function _apply_diseases(I::BitVector, ds::Vector{BitVector})
  for d in ds
    _subseq(d, I) && continue  # already contained → skip

    # Find position with minimal Hamming distance
    best_pos = 1
    best_dist = typemax(Int)
    wnd_end = length(I) - length(d) + 1

    for i in 1:wnd_end
      dist = _hamming(view(I, i:i+length(d)-1), d)
      if dist < best_dist
        best_dist = dist
        best_pos = i
      end
    end

    # Flip the first differing bit inside the best window
    for j in 1:length(d)
      idx = best_pos + j - 1
      if I[idx] != d[j]
        I[idx] = d[j]
        break
      end
    end
  end
  return I
end
