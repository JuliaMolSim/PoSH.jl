
# --------------------------------------------------------------------------
# ACE.jl and SHIPs.jl: Julia implementation of the Atomic Cluster Expansion
# Copyright (c) 2019 Christoph Ortner <christophortner0@gmail.com>
# All rights reserved.
# --------------------------------------------------------------------------


module SphericalHarmonics


import SHIPs
using StaticArrays, LinearAlgebra

const SVec3 = SVector{3}

export SHBasis

# --------------------------------------------------------
#     Indexing
# --------------------------------------------------------

"""
	sizeP(maxDegree)

Return the size of the set of Associated Legendre Polynomials ``P_l^m(x)`` of
degree less than or equal to the given maximum degree
"""
sizeP(maxDegree) = div((maxDegree + 1) * (maxDegree + 2), 2)

"""
	sizeY(maxDegree)

Return the size of the set of real spherical harmonics ``Y_{l,m}(θ,φ)`` of
degree less than or equal to the given maximum degree
"""
sizeY(maxDegree) = (maxDegree + 1) * (maxDegree + 1)

"""
	index_p(l,m)

Return the index into a flat array of Associated Legendre Polynomials ``P_l^m``
for the given indices ``(l,m)``.
``P_l^m`` are stored in l-major order i.e. [P(0,0), [P(1,0), P(1,1), P(2,0), ...]
"""
index_p(l,m) = m + div(l*(l+1), 2) + 1

"""
	index_y(l,m)

Return the index into a flat array of real spherical harmonics ``Y_{l,m}``
for the given indices ``(l,m)``.
``Y_{l,m}`` are stored in l-major order i.e.
[Y(0,0), [Y(1,-1), Y(1,0), Y(1,1), Y(2,-2), ...]
"""
index_y(l,m) = m + l + (l*l) + 1


# --------------------------------------------------------
#     Associated Legendre Polynomials
#     TODO: these are a special case of the
#           Jacobi polynomials so could reuse that code!
# --------------------------------------------------------

"""
TODO: documentation
"""
struct ALPCoefficients
	A::Array{Float64}
	B::Array{Float64}
end

ALPCoefficients(maxDegree::Int) =
	ALPCoefficients( Array{Float64}(undef, sizeP(maxDegree)),
						  Array{Float64}(undef, sizeP(maxDegree)) )

"""
	compute_coefficients(L)

Precompute coefficients ``a_l^m`` and ``b_l^m`` for all l <= L, m <= l
"""
function compute_coefficients(L::Int)
	coeff = ALPCoefficients(L)
	for l in 2:L
		ls = l*l
		lm1s = (l-1) * (l-1)
		for m in 0:(l-2)
			ms = m * m
			coeff.A[index_p(l, m)] = sqrt((4 * ls - 1.0) / (ls - ms))
			coeff.B[index_p(l, m)] = -sqrt((lm1s - ms) / (4 * lm1s - 1.0))
		end
	end
	return coeff
end

"""
	compute_coefficients(L)

Create an array large enough to store an entire set of Associated Legendre
Polynomials ``P_l^m(x)`` of maximum degree L.
"""
allocate_p(L::Int) = Array{Float64}(undef, sizeP(L))

"""
	compute_p(L, x, coeff, P)

Compute an entire set of Associated Legendre Polynomials ``P_l^m(x)``
using the given coefficients, and store in the array P.
"""
function compute_p!(L::Int, x::Float64, coeff::ALPCoefficients,
					     P::Array{Float64,1})
   @assert L > 0
	@assert length(coeff.A) >= sizeP(L)
	@assert length(coeff.B) >= sizeP(L)
	@assert length(P) >= sizeP(L)

	sinθ = sqrt(1.0 - x * x)
	temp = 0.39894228040143267794 # = sqrt(0.5/M_PI)
	P[index_p(0, 0)] = temp

	if (L > 0)
		SQRT3 = 1.7320508075688772935
		P[index_p(1, 0)] = x * SQRT3 * temp
		SQRT3DIV2 = -1.2247448713915890491
		temp = SQRT3DIV2 * sinθ * temp
		P[index_p(1, 1)] = temp

		for l in 2:L
			for m in 0:(l-2)
				P[index_p(l, m)] = coeff.A[index_p(l, m)] *(x * P[index_p(l - 1, m)]
						     + coeff.B[index_p(l, m)] * P[index_p(l - 2, m)])
			end
			P[index_p(l, l - 1)] = x * sqrt(2 * (l - 1) + 3) * temp
			temp = -sqrt(1.0 + 0.5 / l) * sinθ * temp
			P[index_p(l, l)] = temp
		end
	end
	return P
end

"""
dP = dP / dθ (and not dP / dx!!!)
"""
function compute_dp!(L::Int, x::Float64, coeff::ALPCoefficients,
					      P, dP)
   @assert L > 0
	@assert length(coeff.A) >= sizeP(L)
	@assert length(coeff.B) >= sizeP(L)
	@assert length(P) >= sizeP(L)
	@assert length(dP) >= sizeP(L)

	# x = cosθ
	sinθ = sqrt(1.0 - x * x)
	sinθ_dθ = x
	x_dθ = - sinθ

	temp = 0.39894228040143267794 # = sqrt(0.5/M_PI)
	P[index_p(0, 0)] = temp
	dP[index_p(0, 0)] = 0

	SQRT3 = 1.7320508075688772935
	P[index_p(1, 0)] = x * SQRT3 * temp
	dP[index_p(1, 0)] = x_dθ * SQRT3 * temp

	SQRT3DIV2 = -1.2247448713915890491
	temp = SQRT3DIV2 * sinθ * temp
	temp_dθ = SQRT3DIV2 * sinθ_dθ * temp
	P[index_p(1, 1)] = temp
	dP[index_p(1, 1)] = temp_dθ

	for l in 2:L
		for m in 0:(l-2)
			P[index_p(l, m)] =
					coeff.A[index_p(l, m)] * (
						x * P[index_p(l - 1, m)]
					     + coeff.B[index_p(l, m)] * P[index_p(l - 2, m)]
				   )
			dP[index_p(l, m)] =
					coeff.A[index_p(l, m)] * (
						x_dθ * P[index_p(l - 1, m)]
						+ x * dP[index_p(l - 1, m)]
					   + coeff.B[index_p(l, m)] * dP[index_p(l - 2, m)]
				   )
		end
		P[index_p(l, l - 1)] = x * sqrt(2 * (l - 1) + 3) * temp
		dP[index_p(l, l - 1)] = ( x_dθ * sqrt(2 * (l - 1) + 3) * temp
		     							  + x * sqrt(2 * (l - 1) + 3) * temp_dθ )
		temp = -sqrt(1.0 + 0.5 / l) * sinθ * temp
		temp_dθ = ( -sqrt(1.0 + 0.5 / l) * sinθ_dθ * temp
		            -sqrt(1.0 + 0.5 / l) * sinθ * temp_dθ )
		P[index_p(l, l)] = temp
		dP[index_p(l, l)] = temp_dθ
	end
	return P, dP
end


"""
	compute_p(L, x)

Compute an entire set of Associated Legendre Polynomials ``P_l^m(x)`` where
``0 ≤ l ≤ L`` and ``0 ≤ m ≤ l``. Assumes ``|x| ≤ 1``.
"""
function compute_p(L::Int, x::Float64)
	P = Array{Float64}(undef, sizeP(L))
	coeff = compute_coefficients(L)
	compute_p!(L, x, coeff, P)
	return P
end


# ------------------------------------------------------------------------
#                  Spherical Harmonics
# ------------------------------------------------------------------------

"""
R = r(cosφ sinθ, sinφ sinθ, cosθ)
x = sinφ
z = cosθ
s picks the correct inverse of sinφ -> φ
"""
function compute_rxz(R::SVec3{T}) where {T}
   r = norm(R)
   z = R[3] / r
   x = R[2] / sqrt(1 - z^2) / r
   s = sign(R[1])
   return r, x, z, s
end

function cYlm_from_cart!(Y, L, r, x, z, s, P)
	@assert length(P) >= sizeP(L)
	@assert length(Y) >= sizeY(L)
   @assert abs(z) <= 1.0

	INVSQRT2 = 1 / sqrt(2)

	for l = 0:L
		Y[index_y(l, 0)] = P[index_p(l, 0)] * INVSQRT2
	end

   sig = 1
   ep = INVSQRT2
   ep_fact = s * sqrt(1-x^2) + im * x
	for m in 1:L
		sig *= -1
		ep *= ep_fact            # ep =   exp(i *   m  * φ)
		em = sig * conj(ep)      # ep = ± exp(i * (-m) * φ)
		for l in m:L
			p = P[index_p(l,m)]
			Y[index_y(l, -m)] = em * p   # (-1)^m * p * exp(-im*m*phi) / sqrt(2)
			Y[index_y(l,  m)] = ep * p   #          p * exp( im*m*phi) / sqrt(2)
		end
	end

	return Y
end

"""
convert a gradient with respect to spherical coordinates to a gradient
with respect to cartesian coordinates  
"""
function dspher_to_dcart(r, sinφ, cosθ, s, f_φ, f_θ)

end

# x = sinφ, z = cosθ, s = a sign
function cYlm_from_cart_d!(Y, dY, L, r, x, z, s, P, dP)
	@assert length(P) >= sizeP(L)
	@assert length(Y) >= sizeY(L)
   @assert abs(z) <= 1.0

	INVSQRT2 = 1 / sqrt(2)

	for l = 0:L
		Y[index_y(l, 0)] = P[index_p(l, 0)] * INVSQRT2
		dY[index_y(l, 0)] = dspher_to_dcart(r, x, z, s,
														0, dP[index_p(l, 0)] * INVSQRT2)
	end

   sig = 1
   ep = INVSQRT2
	cosφ = sqrt(1-x^2)

   ep_fact = s * cosφ + im * x

	for m in 1:L
		sig *= -1
		ep *= ep_fact            # ep =   exp(i *   m  * φ)
		em = sig * conj(ep)      # ep = ± exp(i * (-m) * φ)
		ep_dφ = im * m * ep
		em_dφ = - im * m * em

		for l in m:L
			p = P[index_p(l,m)]
			Y[index_y(l, -m)] = em * p   # (-1)^m * p * exp(-im*m*phi) / sqrt(2)
			Y[index_y(l,  m)] = ep * p   #          p * exp( im*m*phi) / sqrt(2)

			p_dθ = dP[index_p(l,m)]
			dY[index_y(l, -m)] = dspher_to_dcart(r, x, z, s,
														    em_dφ * p, em * dp)
			dY[index_y(l,  m)] = dspher_to_dcart(r, x, z, s,
															 ep_dφ * p, ep * dp)
		end
	end

	return Y, dY
end


"""
	cYlm_from_xz(L, x, z)

Compute an entire set of real spherical harmonics ``Y_{l,m}(θ, φ)`` for
``x = cos θ, z = sin φ`` where ``0 ≤ l ≤ L`` and ``-l ≤ m ≤ l``.
"""
function cYlm_from_cart(L::Integer, R::SVec3{T}) where {T}
   r, x, z, s = compute_rxz(R)
	P = Vector{T}(undef, sizeP(L))
	coeff = compute_coefficients(L)
	compute_p!(L, z, coeff, P)
	Y = Vector{ComplexF64}(undef, sizeY(L))
	cYlm_from_cart!(Y, L, r, x, z, s, P)
	return Y
end

# ---------------------------------------------
#      Nicer interface
# ---------------------------------------------

struct SHBasis{T}
	maxL::Int
	P::Vector{T}
	coeff::ALPCoefficients
end

SHBasis(maxL::Integer, T=Float64) =
		SHBasis(maxL, Vector{T}(undef, sizeP(maxL)), compute_coefficients(maxL))

Base.length(S::SHBasis) = sizeY(S.maxL)

SHIPs.alloc_B( S::SHBasis{T}) where {T} =
		Vector{Complex{T}}(undef, length(S))
SHIPs.alloc_dB(S::SHBasis{T}) where {T} =
		Vector{SVec3{Complex{T}}}(undef, length(S))

function SHIPs.eval_basis!(Y, S::SHBasis, R::SVec3, L=S.maxL)
	@assert 0 <= L <= S.maxL
	@assert length(Y) >= sizeY(L)
	r, x, z, s = compute_rxz(R)
	compute_p!(L, z, S.coeff, S.P)
	cYlm_from_cart!(Y, L, r, x, z, s, S.P)
	return Y
end


function SHIPs.eval_basis_d!(Y, dY, S::SHBasis, R::SVec3, L=S.maxL)
	@assert 0 <= L <= S.maxL
	@assert length(Y) >= sizeY(L)
	r, x, z, s = compute_rxz(R)
	cYlm_from_cart_d!(Y, L, r, x, z, s, P)
	return Y
end


# ---------------- Clebsch Gordan Stuff


export clebschgordan, cg1



"""
`cg1(j1, m1, j2, m2, j3, m3, T=Float64)` : A reference implementation of
Clebsch-Gordon coefficients based on

https://hal.inria.fr/hal-01851097/document
Equation (4-6)

This heavily uses BigInt and BigFloat and should therefore not be employed
for performance critical tasks.
"""
function cg1(j1, m1, j2, m2, j3, m3, T=Float64)
   if (m3 != m1 + m2) || !(abs(j1-j2) <= j3 <= j1 + j2)
      return zero(T)
   end

   N = (2*j3+1) *
       factorial(big(j1+m1)) * factorial(big(j1-m1)) *
       factorial(big(j2+m2)) * factorial(big(j2-m2)) *
       factorial(big(j3+m3)) * factorial(big(j3-m3)) /
       factorial(big( j1+j2-j3)) /
       factorial(big( j1-j2+j3)) /
       factorial(big(-j1+j2+j3)) /
       factorial(big(j1+j2+j3+1))

   G = big(0)
   # 0 ≦ k ≦ j1+j2-j3
   # 0 ≤ j1-m1-k ≤ j1-j2+j3   <=>   j2-j3-m1 ≤ k ≤ j1-m1
   # 0 ≤ j2+m2-k ≤ -j1+j2+j3  <=>   j1-j3+m2 ≤ k ≤ j2+m2
   lb = (0, j2-j3-m1, j1-j3+m2)
   ub = (j1+j2-j3, j1-m1, j2+m2)
   for k in maximum(lb):minimum(ub)
      bk = big(k)
      G += (-1)^k *
           binomial(big( j1+j2-j3), big(k)) *
           binomial(big( j1-j2+j3), big(j1-m1-k)) *
           binomial(big(-j1+j2+j3), big(j2+m2-k))
   end

   return T(sqrt(N) * G)
end

clebschgordan = cg1

end