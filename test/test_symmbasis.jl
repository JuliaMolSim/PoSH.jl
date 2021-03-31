
# --------------------------------------------------------------------------
# ACE.jl: Julia implementation of the Atomic Cluster Expansion
# Copyright (c) 2019 Christoph Ortner <christophortner0@gmail.com>
# All rights reserved.
# --------------------------------------------------------------------------


@testset "SymmetricBasis"  begin

#---


using ACE
using Random, Printf, Test, LinearAlgebra, ACE.Testing
using ACE: evaluate, evaluate_d, SymmetricBasis, NaiveTotalDegree, PIBasis
using ACE.Random: rand_rot, rand_refl

# Extra using Wigner for computing Wigner Matrix
using ACE.Wigner


# construct the 1p-basis
D = NaiveTotalDegree()
maxdeg = 6
ord = 3

B1p = ACE.Utils.RnYlm_1pbasis(; maxdeg=maxdeg, D = D)

# generate a configuration
nX = 10
X0 = rand(EuclideanVectorState, B1p.bases[1])
Xs = rand(EuclideanVectorState, B1p.bases[1], nX)

#---

@info("SymmetricBasis construction and evaluation: Invariant Scalar")

φ = ACE.Invariant()
pibasis = PIBasis(B1p, ord, maxdeg; property = φ)
basis = SymmetricBasis(pibasis, φ)

BB = evaluate(basis, Xs, X0)

# a stupid but necessary test
BB1 = basis.A2Bmap * evaluate(basis.pibasis, Xs, X0)
println(@test isapprox(BB, BB1, rtol=1e-10))

for ntest = 1:30
      Xs1 = shuffle(rand_refl(rand_rot(Xs)))
      BB1 = evaluate(basis, Xs1, X0)
      print_tf(@test isapprox(BB, BB1, rtol=1e-10))
end

#---

L = 1
φ = ACE.SphericalVector(L)
pibasis = PIBasis(B1p, ord, maxdeg; property = φ
      )
basis = SymmetricBasis(pibasis, φ
      )

Xs = rand(EuclideanVectorState, B1p.bases[1], nX)
BB = evaluate(basis, Xs, X0)

function rotz(α)
	return [cos(α) -sin(α) 0; sin(α) cos(α) 0; 0 0 1];
end

function roty(α)
	return [cos(α) 0 sin(α); 0 1 0;-sin(α) 0 cos(α)];
end

function Ang2Mat_zyz(α,β,γ)
	return rotz(α)*roty(β)*rotz(γ);
end

for ntest = 1:30
      α = 2pi*rand(Float64);
      β = pi*rand(Float64);
      γ = 2pi*rand(Float64);
      Q = Ang2Mat_zyz(α,β,γ);
      Q = SMatrix{3,3}(Q);
      Xs1 = shuffle(Xs);
	for i=1:nX
		Xs1[i]=Q*Xs1[i];
	end
      BB1 = evaluate(basis, Xs1, X0)
      print_tf(@test isapprox(rot_D(φ, Q) * BB, BB1, rtol=1e-10))
end

# function Main_test(nn::StaticVector{T}, ll::StaticVector{T}, φ::Orbitaltype, R::SVector{N, Float64}) where{T,N}
# 	result_R = Evaluate(nn,ll,φ,R)[1];
# 	α = 2pi*rand(Float64);
# 	β = pi*rand(Float64);
# 	γ = 2pi*rand(Float64);
# 	Q = Ang2Mat_zyz(α,β,γ);
# 	Q = SMatrix{3,3}(Q);
# 	RR = Rot(R, Q);
# 	result_RR = Evaluate(nn,ll,φ,RR)[1];
# 	println("Is F(R) ≈ D(Q)F(QR)?")
# 	return result_RR ≈ rot_D(φ, Q) * result_R
# end

# #---
# @info("Basis construction and evaluation checks")
# @info("check single species")
# Nat = 15
# Rs, Zs, z0 = rand_nhd(Nat, Pr, :X)
# B = evaluate(rpibasis, Rs, Zs, z0)
# println(@test(length(rpibasis) == length(B)))
# dB = evaluate_d(rpibasis, Rs, Zs, z0)
# println(@test(size(dB) == (length(rpibasis), length(Rs))))
# B_, dB_ = evaluate_ed(rpibasis, Rs, Zs, z0)
# println(@test (B_ ≈ B) && (dB_ ≈ dB))
#
# #---
# @info("check multi-species")
# maxdeg = 5
# Pr = transformed_jacobi(maxdeg, trans, rcut; pcut = 2)
# species = [:C, :O, :H]
# P1 = ACE.RnYlm1pBasis(Pr; species = species, D = D)
# basis = ACE.RPIBasis(P1, N, D, maxdeg)
# Rs, Zs, z0 = ACE.rand_nhd(Nat, Pr, species)
# B = evaluate(basis, Rs, Zs, z0)
# println(@test(length(basis) == length(B)))
# dB = evaluate_d(basis, Rs, Zs, z0)
# println(@test(size(dB) == (length(basis), length(Rs))))
# B_, dB_ = evaluate_ed(basis, Rs, Zs, z0)
# println(@test (B_ ≈ B) && (dB_ ≈ dB))
#
# #---
#
# degrees = [ 12, 10, 8, 8, 8, 8 ]
#
# @info("Check a few basis properties ")
# # for species in (:X, :Si) # , [:C, :O, :H])
# for species in (:X, :Si, [:C, :O, :H]), N = 1:length(degrees)
#    local Rs, Zs, z0, B, dB, basis, D, P1, Nat
#    Nat = 15
#    D = SparsePSHDegree()
#    P1 = ACE.RnYlm1pBasis(Pr; species = species)
#    basis = ACE.RPIBasis(P1, N, D, degrees[N])
#    @info("species = $species; N = $N; deg = $(degrees[N]); len = $(length(basis))")
#    @info("   check (de-)serialization")
#    println(@test(all(JuLIP.Testing.test_fio(basis))))
#    @info("   isometry and permutation invariance")
#    for ntest = 1:30
#       Rs, Zs, z0 = ACE.rand_nhd(Nat, Pr, species)
#       Rsp, Zsp = ACE.rand_sym(Rs, Zs)
#       print_tf(@test(evaluate(basis, Rs, Zs, z0) ≈
#                      evaluate(basis, Rsp, Zsp, z0)))
#    end
#    println()
#    @info("   check derivatives")
#    for ntest = 1:30
#       Rs, Zs, z0 = ACE.rand_nhd(Nat, Pr, species)
#       B = evaluate(basis, Rs, Zs, z0)
#       dB = evaluate_d(basis, Rs, Zs, z0)
#       Us = [ rand(eltype(Rs)) .- 0.5 for _=1:length(Rs) ]
#       dB_dUs = transpose.(dB) * Us
#       errs = []
#       for p = 2:12
#          h = 0.1^p
#          B_h = evaluate(basis, Rs + h * Us, Zs, z0)
#          dB_h = (B_h - B) / h
#          # @show norm(dAA_h - dAA_dUs, Inf)
#          push!(errs, norm(dB_h - dB_dUs, Inf))
#       end
#       success = (/(extrema(errs)...) < 1e-3) || (minimum(errs) < 1e-10)
#       print_tf(@test success)
#    end
#    println()
#    @info("   check combine")
#    coeffs = randcoeffs(basis)
#    V = combine(basis, coeffs)
#    Vst = standardevaluator(V)
#    for ntest = 1:30
#       Rs, Zs, z0 = ACE.rand_nhd(Nat, Pr, species)
#       v = evaluate(V, Rs, Zs, z0)
#       vst = evaluate(Vst, Rs, Zs, z0)
#       cdotB = dot(coeffs, evaluate(basis, Rs, Zs, z0))
#       print_tf(@test v ≈ cdotB ≈ vst)
#    end
#    println()
#    @info("   check graph evaluator")
#    basisst = standardevaluator(basis)
#    for ntest = 1:30
#       env = ACE.rand_nhd(Nat, Pr, species)
#       print_tf(@test evaluate(basisst, env...) ≈ evaluate(basis, env...))
#       print_tf(@test evaluate_d(basisst, env...) ≈ evaluate_d(basis, env...))
#    end
#    println()
# end
#

#---

end
