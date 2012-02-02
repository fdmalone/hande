module importance_sampling

! Module for applying importance sampling transforms to the Hamiltonian, e.g. to
! stochastically sample \tilde{H}_{ij} = f(i) H_{ij} 1/f(j) rather than just
! H_{ij}.

! In order to be accessible via a common function pointer, these subroutines
! should have the interface defined by i_trial_fn.

use const

implicit none

contains

    subroutine neel_trial_state(cdet, connection, hmatel)

        ! Apply the transformation to the Hamiltonian matrix element due to
        ! useing the Neel singlet state as the trial function.

        ! In:
        !    cdet: info on the current determinant (cdet) that we will spawn
        !        from.
        !    connection: excitation connection between the current determinant
        !        and the child determinant, on which progeny are spawned.
        ! In/Out:
        !    hmatel: on input, untransformed matrix element connecting two spin
        !        functions (kets).  On output, transformed matrix element,
        !        \Psi_i^T H_{ij} 1/\Psi_j^T.

        use basis, only: bit_lookup, basis_length
        use determinants, only: det_info, lattice_mask
        use excitations, only: excit
        use fciqmc_data, only: neel_singlet_amp, sampling_size

        type(det_info), intent(in) :: cdet
        type(excit), intent(in) :: connection
        real(p), intent(inout) :: hmatel

        integer :: up_spins_to, up_spins_from
        integer :: bit_position, bit_element

        ! Find the number of up spins on sublattice 1.
        up_spins_from = nint(cdet%data(sampling_size+1))
        ! For the spin up which was flipped to create the connected
        ! basis function, find whether this spin was on sublattice 1 or 2.
        ! If it was on sublattice 1, the basis function we go to has 1 less
        ! up spin on sublattice 1, else it will have one more spin up here.
        bit_position = bit_lookup(1,connection%from_orb(1))
        bit_element = bit_lookup(2,connection%from_orb(1))
        if (btest(lattice_mask(bit_element), bit_position)) then
            up_spins_to = up_spins_from-1
        else
            up_spins_to = up_spins_from+1
        end if

        ! For a given number of spins up on sublattice 1, n, the corresponding
        ! ampltidue of this basis function in the trial function is stored as
        ! neel_singlet_amp(n), for this particular trial function. Hence we have:
        hmatel = (neel_singlet_amp(up_spins_to)*hmatel)/neel_singlet_amp(up_spins_from)

    end subroutine neel_trial_state

end module importance_sampling
