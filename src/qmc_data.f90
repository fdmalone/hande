module qmc_data

use const
use spawn_data, only: spawn_t
use calc, only: parallel_t

implicit none

! [review] - FDM: I think some or all of the following should be in calc.
! [review] - NSB: Yes that seems reasonable. We could perhaps do with some
! [review] - NSB: derived types for holding calculation options specific to
! [review] - NSB: each method (FCIQMC, CCMC, DMQMC...), and they should go
! [review] - NSB: in calc I guess. These variables look mostly to do with
! [review] - NSB: DMQMC options. Then qmc_data should contain derived types
! [review] - NSB: for various data objects used by those methods, which looks
! [review] - NSB: like what is happening, so it looks good to me.
! [review] - JSS: Agree with NSB.  There should be a derived type for settings common to
! [review] - JSS: all the QMC methods as well.  Only input *options* should be moved to
! [review] - JSS: calc though (ie telling the calculation what to do).  The results of
! [review] - JSS: the calculation should be in a *_data module.

! Don't bother renormalising generation probabilities; instead allow forbidden
! excitations to be generated and then rejected.
logical :: no_renorm = .false.

! probability of attempting single or double excitations...
! set to be nonsense value so can easily detect if it's given as an input option
real(p) :: pattempt_single = -1, pattempt_double = -1

! True if allowing non-integer values for psip populations.
logical :: real_amplitudes = .false.

! If this logical is true then the program runs the DMQMC algorithm with
! importance sampling.
! dmqmc_sampling_prob stores the factors by which the probabilities of
! spawning to a larger excitation are reduced by. So, when spawning from
! a diagonal element to a element with one excitation, the probability
! of spawning is reduced by a factor dmqmc_sampling_probs(1).
! dmqmc_accumulated_probs(i) stores the multiplication of all the elements
! of dmqmc_sampling_probs up to the ith element. This quantity is often
! needed, so it is stored.
logical :: dmqmc_weighted_sampling
! If dmqmc_vary_weights is true, then instead of using the final sampling
! weights for all the iterations, the weights will be gradually increased
! until finish_varying_weights, at which point they will be held constant.
! weight_altering_factors stores the factors by which each weight is
! multiplied at each step. 
logical :: dmqmc_vary_weights = .false.
! If this logical is true then the program will calculate the ratios
! of the numbers of the psips on neighbouring excitation levels. These
! are output so that they can be used when doing importance sampling
! for DMQMC, so that each level will have roughly equal numbers of psips.
! The resulting new weights are used in the next beta loop.
logical :: dmqmc_find_weights = .false.
! Calculate replicas (ie evolve two wavefunctions/density matrices at once)?
! Currently only implemented for DMQMC.
logical :: replica_tricks = .false.
! If true then the simulation will start with walkers uniformly distributed
! along the diagonal of the entire density matrix, including all symmetry
! sectors.
logical :: all_sym_sectors = .false.
! If half_density_matrix is true then half the density matrix will be 
! calculated by reflecting spawning onto the lower triangle into the
! upper triangle. This is allowed because the density matrix is 
! symmetric.
logical :: half_density_matrix = .false.

! If true then the reduced density matricies will be calulated for the 'A'
! subsystems specified by the user.
logical :: doing_reduced_dm = .false.

! If true then each subsystem A RDM specified by the user will be accumulated
! from the iteration start_averaging until the end of the beat loop, allowing
! ground-state estimates of the RDMs to be calculated.
logical :: calc_ground_rdm = .false.

! If true then the reduced density matricies will be calculated for each
! subsystem specified by the user at the end of each report loop. These RDMs
! can be used to calculate instantaeous estimates at the given beta value.
! They are thrown away after these calculation has been performed on them.
logical :: calc_inst_rdm = .false.

! If true then calculate the concurrence for reduced density matrix of two sites.
logical :: doing_concurrence = .false.

! If true then calculate the von Neumann entanglement entropy for specified subsystem.
logical :: doing_von_neumann_entropy = .false.

! If true then, if doing an exact diagonalisation, calculate and output the
! eigenvalues of the reduced density matrix requested.
logical :: doing_exact_rdm_eigv=.false.

! For DMQMC: If this locial is true then the fraction of psips at each
! excitation level will be output at each report loop. These fractions
! will be stored in the array below.
! The number of excitations for a given system is defined by
! sys_t%max_number_excitations; see comments in sys_t for more details.
logical :: calculate_excit_distribution = .false.
! If true then the reduced density matrix is output to a file, 'reduced_dm'
! each beta loop.
logical :: output_rdm

! The unit of the file reduced_dm.
! {review] - JSS: this appears to be no longer used.
integer :: rdm_unit

!--- Restart data ---

! Restart calculation from file.
logical :: restart = .false.

! Print out restart file.
logical :: dump_restart_file = .false.

! Print out a restart file before the shift turns on.
logical :: dump_restart_file_shift = .false.

! Restart data.
! [review] - JSS: not an input option.
integer :: mc_cycles_done = 0

! How often do we change the reference determinant to the determinant with
! greatest population?
! Default: we don't.
integer :: select_ref_det_every_nreports = huge(1)
! Also start with D0_population on i_s|D_0>, where i_s is the spin-version
! operator.  This is only done if no restart file is used *and* |D_0> is not
! a closed shell determinant.
logical :: init_spin_inv_D0 = .false.

! Type for storing parallel information: see calc for description.
! [review] - JSS: not an input option.
type(parallel_t) :: par_info

! Are we doing a timestep search
logical :: tau_search = .false.

! [review] - FDM: End of suggestions for move to calc.

!--- Reference determinant ---
type reference_t
    ! Bit string of reference determinant.
    integer(i0), allocatable, target :: f0(:)
    ! List of occupied orbitals in reference determinant.
    integer, allocatable :: occ_list0(:)
    ! Bit string of reference determinant used to generate the Hilbert space.
    ! This is usually identical to f0, but not necessarily (e.g. if we're doing
    ! a spin-flip calculation).
    integer(i0), allocatable, target :: hs_f0(:)
    ! hs_f0:hs_occ_list0 as f0:occ_list0.
    integer, allocatable :: hs_occ_list0(:)
    ! Population of walkers on reference determinant.
    ! The initial value can be overridden by a restart file or input option.
    ! For DMQMC, this variable stores the initial number of psips to be
    ! randomly distributed along the diagonal elements of the density matrix.
    ! [review] - JSS: is 10 a good default still?  It's not for CCMC or DMQMC...
    real(p) :: D0_population = 10.0_p
    ! Energy of reference determinant.
    real(p) :: H00
    ! Factor by which the population on a determinant must exceed the reference
    ! determinant's population in order to be accepted as the new reference
    ! determinant.
    real(p) :: ref_det_factor = 1.50_p
end type reference_t

! [review] - JSS: RDMs here are DMQMC-specific.  Should there be further dmqmc_data, fciqmc_data,
! [review] - JSS: ccmc_data, etc modules?
! [review] - NSB: Yes, I think that's sensible.

! Spawned lists for rdms.
type rdm_spawn_t
    type(spawn_t) :: spawn
    ! Spawn with the help of a hash table to avoid a sort (which is extremely
    ! expensive when a large number of keys are repeated--seem to hit worst case
    ! performance in quicksort).
    type(hash_table_t) :: ht
end type rdm_spawn_t

! This type contains information for the RDM corresponding to a given
! subsystem. It takes translational symmetry into account by storing information
! for all subsystems which are equivalent by translational symmetry.
type rdm_t
    ! The total number of sites in subsystem A.
    integer :: A_nsites
    ! Similar to string_len, rdm_string_len is the length of the byte array
    ! necessary to contain a bit for each subsystem-A basis function. An array
    ! of twice this length is stored to hold both RDM indices.
    integer :: rdm_string_len
    ! The sites in subsystem A, as entered by the user.
    integer, allocatable :: subsystem_A(:)
    ! B_masks(:,i) has bits set at all bit positions corresponding to sites in
    ! version i of subsystem B, where the different 'versions' correspond to
    ! subsystems which are equivalent by symmetry.
    integer(i0), allocatable :: B_masks(:,:)
    ! bit_pos(i,j,1) contains the position of the bit corresponding to site i in 
    ! 'version' j of subsystem A.
    ! bit_pos(i,j,2) contains the element of the bit corresponding to site i in
    ! 'version' j of subsystem A.
    ! Note that site i in a given version is the site that corresponds to site i 
    ! in all other versions of subsystem A (and so bit_pos(i,:,1) and
    ! bit_pos(i,:,2) will not be sorted). This is very important so that
    ! equivalent psips will contribute to the same RDM element.
    integer, allocatable :: bit_pos(:,:,:)
    ! Two bitstrings of length rdm_string_len. To be used as temporary
    ! bitstrings to prevent having to regularly allocate different length
    ! bitstrings for different RDMs.
    integer(i0), allocatable :: end1(:), end2(:)
end type rdm_t

! [review] - NSB: This is actually constant, so I've moved here (for now) and
! [review] - NSB: changed it to a parameter. This can probably be global data
! [review] - NSB: since it is constant.
! [review] - JSS: Applicable only to Heisenberg model?  If so, please can it have a more specific name?
! [review] - NSB: I don't think so, its a matrix used in calculating concurrence
! [review] - NSB: which is more general (in theory at least)
! This will store the 4x4 flip spin matrix \sigma_y \otimes \sigma_y if
! concurrence is to be calculated.
real(p), parameter :: flip_spin_matrix(4,4) = (\ 0.0_p,  0.0_p, 0.0_p, -1.0_p,  &
                                                0.0_p,  0.0_p, 1.0_p,  0.0_p,  &
                                                0.0_p,  1.0_p, 0.0_p,  0.0_p,  &
                                               -1.0_p,  0.0_p, 0.0_p,  0.0_p  \)

! [review] - NSB: dmqmc_t was very large, and I think can be split up a bit more
! [review] - NSB: logically. I've created derived types for ground-state RDMs and
! [review] - NSB: instantaneous RDMs, and for the weighted sampling.
! [review] - JSS: split this into input-level data and calculation-derived data.
! [review] - NSB: Agree, will do.
type dmqmc_estimates_t
    ! [review] - NSB: dmqmc_factor is a bit of a wierd one because it is used more
    ! [review] - NSB: more generally by other methods, too. It is just a number
    ! [review] - NSB: which is set to 2 for DMQMC, or to 1 otherwise.
    ! [review] - NSB: It is a fundamental property of the equation that we evolve with...
    ! [review] - NSB: Suggestions on where to put this?
    ! When performing dmqmc calculations, dmqmc_factor = 2.0. This factor is
    ! required because in DMQMC calculations, instead of spawning from one end with
    ! the full probability, we spawn from two different ends with half probability each.
    ! Hence, tau is set to tau/2 in DMQMC calculations, so that an extra factor is not
    ! required in every spawning routine. In the death step however, we use
    ! walker_energies(1,idet), which has a factor of 1/2 included for convenience
    ! already, for conveniece elsewhere. Hence we have to multiply by an extra factor
    ! of 2 to account for the extra 1/2 in tau. dmqmc_factor is set to 1.0 when not
    ! performing a DMQMC calculation, and so can be ignored in these cases.
    real(p) :: dmqmc_factor = 1.0_p

    ! This variable stores the number of estimators which are to be
    ! calculated and printed out in a DMQMC calculation.
    integer :: number_dmqmc_estimators = 0
    ! The integers below store the index of the element in the array
    ! estimator_numerators, in which the corresponding thermal quantity is
    ! stored. In general, a different number and combination of estimators
    ! may be calculated, and hence we need a way of knowing which element
    ! refers to which operator. These indices give labels to operators.
    ! They will be set to 0 if no used, or else their positions in the array,
    ! from 1-number_dmqmc_estimators.
    ! [review] - JSS: can this be turned into an enum?  estimator_numerators is small, so
    ! [review] - JSS: we may as well allocate an element for every possible data type to
    ! [review] - JSS: make the code simpler.
    ! [review] - NSB: Yes that seems sensible.
    integer :: energy_index = 0
    integer :: energy_squared_index = 0
    integer :: correlation_index = 0
    integer :: staggered_mag_index = 0
    integer :: full_r2_index = 0

    ! In DMQMC the trace of the density matrix is an important quantity
    ! used in calculating all thermal estimators. This quantity stores
    ! the this value, Tr(\rho), where rho is the density matrix which
    ! the DMQMC algorithm calculates stochastically.
    real(p), allocatable :: trace(:) ! (sampling_size)
    ! estimator_numerators stores all the numerators for the estimators in DMQMC
    ! which the user has asked to be calculated. These are, for a general
    ! operator O which we wish to find the thermal average of:
    ! \sum_{i,j} \rho_{ij} * O_{ji}
    ! This variabe will store this value from the first iteration of each
    ! report loop. At the end of a report loop, the values from each
    ! processor are combined and stored in estimator_numerators on the parent
    ! processor. This is then output, and the values of estimator_numerators
    ! are reset on each processor to start the next report loop.
    real(p), allocatable :: estimator_numerators(:) !(number_dmqmc_estimators)

    ! correlation_mask is a bit string with a 1 at positions i and j which
    ! are considered when finding the spin correlation function, C(r_{i,j}).
    ! All other bits are set to 0. i and j are chosen by the user initially.
    ! [review] - JSS: both input-derived data.
    ! [review] - NSB: True, but its not really an input option, so I'm not
    ! [review] - NSB: sure it belongs in an input type. Is that what you're
    ! [review] - suggesting? They're perhaps more system, or estimator related.
    integer(i0), allocatable :: correlation_mask(:) ! (string_len)
    ! correlation_sites stores the site positions specified by the users
    ! initially (as orbital labels).
    integer, allocatable :: correlation_sites(:)

    ! When using the replica_tricks option, if the rdm in the first
    ! simulation if denoted \rho^1 and the ancillary rdm is denoted
    ! \rho^2 then renyi_2 holds:
    ! x = \sum_{ij} \rho^1_{ij} * \rho^2_{ij}.
    ! The indices of renyi_2 hold this value for the various rdms being
    ! calculated. After post-processing averaging, this quantity should
    ! be normalised by the product of the corresponding RDM traces.
    ! call it y. Then the renyi-2 entropy is then given by -log_2(x/y).
    ! [review] - JSS: dimensions?
    ! [review] - NSB: It has dimensions nrdms, which belongs to 
    ! [review] - NSB: dmqmc_inst_rdms_t. It should probably be
    ! [review] - NSB: moved there, agreed?
    real(p), allocatable :: renyi_2(:)

    real(p), allocatable :: excit_distribution(:) ! (0:max_number_excitations)

    ! [review] - NSB: This is used both for excit_distribution and ground-state
    ! [review] - NSB: I should create a new variable for the ground-state
    ! [review] - NSB: RDMs and add it to that derived type.
    ! When calculating certain DMQMC properties, we only want to start
    ! averaging once the ground state is reached. The below integer is input
    ! by the user, and gives the iteration at which data should start being
    ! accumulated for the quantity. This is currently only used for the
    ! reduced density matrix and calculating importance sampling weights.
    integer :: start_averaging = 0

    ! [review] - NSB: I might remove these two - I doubt they'll ever be used.
    ! In DMQMC, the user may want want the shift as a function of beta to be
    ! the same for each beta loop. If average_shift_until is non-zero then
    ! shift_profile is allocated, and for the first average_shift_until
    ! beta loops, the shift is stored at each beta value and then averaged
    ! over all these beta loops afterwards. These shift values are stored
    ! in shift profile, and then used in future beta loops as the shift
    ! profile for each one.
    ! When average_shift_until is set equal to -1, all the averaging has
    ! finished, and the algorithm uses the averaged values stored in
    ! shift_profile.
    integer :: average_shift_until = 0
    real(p), allocatable :: shift_profile(:) ! (nreport)
end type dmqmc_estimates_t


!--- Type for all instantaneous RDMs ---
type dmqmc_inst_rdms_t
    ! The total number of rdms beings calculated.
    integer :: nrdms
    ! The total number of translational symmetry vectors.
    ! This is only set and used when performing rdm calculations.
    integer :: nsym_vec

    ! This stores all the information for the various RDMs that the user asks
    ! to be calculated. Each element of this array corresponds to one of these RDMs.
    type(rdm_t), allocatable :: rdms(:) ! nrdms

    ! rdm_traces(i,j) holds the trace of replica i of the rdm with label j.
    real(p), allocatable :: rdm_traces(:,:) ! (sampling_size, nrdms)

    type(rdm_spawn_t), allocatable :: rdm_spawn(:) ! nrdms

    ! The length of the spawning array for RDMs. Each RDM calculated has the same
    ! length array.
    integer :: spawned_rdm_length
end type dmqmc_inst_rdms_t


!--- Type for a ground state RDM ---
type dmqmc_ground_rdm_t
    ! This stores the reduces matrix, which is slowly accumulated over time
    ! (on each processor).
    real(p), allocatable :: reduced_density_matrix(:,:)
    ! The trace of the ground-state RDM.
    ! TODO: Currently ground-state RDMs use the global rdm_traces, the same
    !       as instantaneous RDMs. This needs updating.
    real(p) :: trace
end type dmqmc_ground_rdm_t


!--- Type for weighted sampling parameters ---
type dmqmc_weighted_sampling_t
    real(p), allocatable :: dmqmc_sampling_probs(:) ! (min(nel, nsites-nel))
    real(p), allocatable :: dmqmc_accumulated_probs(:) ! (min(nel, nsites-nel) + 1)
    real(p), allocatable :: dmqmc_accumulated_probs_old(:) ! (min(nel, nsites-nel) + 1)

    integer :: finish_varying_weights = 0
    real(dp), allocatable :: weight_altering_factors(:)
end type dmqmc_weighted_sampling_t

! [review] - FDM: Not sure where this belongs.
! [review] - NSB: I'm not sure either... perhaps an FCIQMC importance sampling type?
! [review] - NSB: This is a constant for a given system, so maybe in a Heisenberg system type?
! [review] - JSS: does appear to be a Heisenberg system type.  We could also create a fciqmc
! [review] - JSS: importance sampling type, which could be useful later on.
! When using the Neel singlet trial wavefunction, it is convenient
! to store all possible amplitudes in the wavefunction, since
! there are relativley few of them and they are expensive to calculate
real(dp), allocatable :: neel_singlet_amp(:) ! (nsites/2) + 1

! [review] - FDM: Not sure where this belongs (spawned_walkers / walkers?).
! [review] - NSB: This this isn't used and should be removed.
real(dp) :: annihilation_comms_time = 0.0_dp

!--- Folded spectrum data ---
! [review] - JSS: input options (also, should we just delete folded spectrum?)
! [review] - NSB: I wouldn't mind, but I'll have to leave it up to you.
type folded_spect_t
    ! The line about which you are folding i.e. eps in (H-eps)^2 - E_0
    real(p) :: fold_line = 0
    ! The generation probabilities of a dual excitation type
    real(p) :: P__=0.05, Po_=0.475, P_o=0.475
    ! The split generation normalisations
    real(p) :: X__=0, Xo_=0, X_o=0
end type folded_spect_t

! [review] - JSS: input options (also, should we remove initiator_cas?)
! [review] - NSB: Yes I think that initiator_cas should be removed.
type initiator_t
    ! Complete active space within which a determinant is an initiator.
    ! (0,0) corresponds to the reference determinant only.
    integer :: initiator_cas(2) = (/ 0,0 /)
    ! Population above which a determinant is an initiator.
    real(p) :: initiator_population = 3.0_p
end type initiator_t

! [review] - FDM: Should determ_hash_t and semi_stoch_t be in semi_stoch.F90?
! [review] - NSB: There was I good reason I moved them to fciqmc_data, but I
! [review] - NSB: can't remember... I think it must have been a circular
! [review] - NSB: dependence but can't see why. If it doesn't cause problems then
! [review] - NSB: let's try and move them back to semi_stoch.F90.
! [review] - JSS: Looks like they were moved to fciqmc_data in aab941d1 to avoid a circular
! [review] - JSS: dependency involving annihilation.
! [review[ - NSB: OK, I say leave here for now and then see if there's somewhere
! [review] - NSB: better to move it later.

! Array to hold the indices of deterministic states in the dets array, accessed
! by calculating a hash value. This type is used by the semi_stoch_t type and
! is intended only to be used by this object.
type determ_hash_t
    ! For an example of how to use this type to see if a determinant is in the
    ! deterministic space or not, see the routine check_if_determ.

    !rSeed used in the MurmurHash function to calculate hash values.
    integer :: seed
    ! The size of the hash table (ignoring collisions).
    integer :: nhash
    ! The indicies of the determinants in the semi_stoch_t%dets array.
    ! Note that element nhash+1 should be set equal to determ%tot_size+1.
    ! This helps with avoiding out-of-bounds errors when using this object.
    integer, allocatable :: ind(:) ! (semi_stoch_t%tot_size)
    ! hash_ptr(i) stores the index of the first index in the array ind which
    ! corresponds to a determinant with hash value i.
    ! This is similar to what is done in the CSR sparse matrix type (see
    ! csr.f90).
    integer, allocatable :: hash_ptr(:) ! (nhash+1)
end type determ_hash_t

type semi_stoch_t
    ! If true, then the deterministic 'spawning' will be performed in a routine
    ! with an extra MPI call. This routine handles all of the annihilation of
    ! deterministic spawnings with a simple summing of vectors.
    ! If false, then the deterministic spawnings are added to the spawned list
    ! and treated with the standard annihilation routine.
    logical :: separate_annihilation
    ! Integer to specify which type of deterministic space is being used.
    ! See the various determ_space parameters defined above.
    integer :: space_type = empty_determ_space
    ! The total number of deterministic states on all processes.
    integer :: tot_size
    ! sizes(i) holds the number of deterministic states belonging to process i.
    integer, allocatable :: sizes(:) ! (0:nproc-1)
    ! The Hamiltonian in the deterministic space, stored in a sparse CSR form.
    ! An Hamiltonian element, H_{ij}, is stored in hamil if and only if both
    ! i and j are in the deterministic space.
    type(csrp_t) :: hamil
    ! This array is used to store the values of amplitudes of deterministic
    ! states throughout a QMC calculation.
    real(p), allocatable :: vector(:) ! sizes(iproc)
    ! If separate_annihilation is true, then an extra MPI call is used to join
    ! together the the deterministic vector arrays from each process. This
    ! array is used to hold the results, which will be the list of all
    ! deterministic amplitudes.
    ! If separate_annihilation is not true then this array will remain
    ! deallocated.
    real(p), allocatable :: full_vector(:) ! tot_size
    ! If separate_annihilation is true then this array will hold the indices
    ! of the deterministic states in the main list. This prevents having to
    ! search the whole of the main list for the deterministic states.
    ! If separate_annihilation is not true then this array will remain
    ! deallocated.
    integer, allocatable :: indices(:) ! sizes(iproc)
    ! dets stores the deterministic states across all processes.
    ! All states on process 0 are stored first, then process 1, etc...
    integer(i0), allocatable :: dets(:,:) ! (string_len, tot_size)
    ! A hash table which allows the index of a determinant in dets to be found.
    ! This is done by calculating the hash value of the given determinant.
    type(determ_hash_t) :: hash_table
    ! Deterministic flags of states in the main list. If determ_flags(i) is
    ! equal to 0 then the corresponding state in position i of the main list is
    ! a deterministic state, else it is not.
    integer, allocatable :: flags(:)
end type semi_stoch_t

! [review] - FDM: Not sure how to organise semi-stochastic data given that there already exists a semi_stoch_t object.
! [review] - NSB: A semi_stoch_t refers to a particular instance of a deterministic space. Most of the following
! [review] - NSB: refer to options input into the semi-stochastic initialisation routine. They should probably be
! [review] - NSB: in a derived type for semi-stochastic options in calc.
!--- Semi-stochastic input ---
enum, bind(c)
    ! This option uses an empty deterministic space, and so turns
    ! semi-stochastic off.
    enumerator :: empty_determ_space
    ! This space is generated by choosing the determinants with the highest
    ! populations in the main walker list, at the point the deterministic space
    ! is generated.
    enumerator :: high_pop_determ_space
    ! This option generates the deterministic space by reading the states in
    ! from an HDF5 file (named SEMI.STOCH.*.H5).
    enumerator :: read_determ_space
end enum
! The iteration on which to turn on the semi-stochastic algorithm using the
! parameters deterministic space specified by determ_space_type.
integer :: semi_stoch_start_iter = 0
! determ_space_type is used to tell the semi-stochastic initialisation routine
! which type of deterministic space to use. See the 'determ-space' parameters
! defined in semi_stoch.F90 for the various values it can take.
integer :: determ_space_type = 0
! Certain deterministic space types need a target size to be input to tell the
! semi-stochastic initialisation routine how many states to try and include. In
! such cases this variable should be set on input.
integer :: determ_target_size = 0
! If true then the deterministic states will be written to a file.
logical :: write_determ_space = .false.
! If true then deterministic spawnings will not be added to the spawning list
! but rather treated separately via an extra MPI call.
logical :: separate_determ_annihil = .true.

! ---- CCMC input ---

type ccmc_t
    ! How frequently (in log_2) an excitor can be moved to a different processor.
    ! See comments in spawn_t and assign_particle_processor.
    integer :: ccmc_move_freq = 5
    ! Value of cluster%amplitude/cluster%pselect above which spawns are split up
    ! The default value corresponds to off.
    real(p) :: cluster_multispawn_threshold = huge(1.0_p)
end type ccmc_t

! [review] - JSS: split into input options and data arising from the calc.
type shift_t
    ! shift: the shift is held constant at the initial value (from input) unless
    ! vary_shift is true. When the replica_tricks option is used, the elements
    ! of the shift array refer to the shifts in the corresponding replica systems.
    ! When replica_tricks is not being used, only the first element is used.
    ! vary_shift_from_proje: if true, then the when variable shift mode is entered
    ! the shift is set to be the current projected energy.
    ! vary_shift_from: if vary_shift_from_proje is false, then the shift is set to
    ! this value when variable shift mode is entered.
    ! warning: if both initial_shift and vary_shift_from are set, then we expect the
    ! user to have been sensible.
    real(p), allocatable, target :: shift(:) ! (sampling_size)
    real(p) :: vary_shift_from = 0.0_p
    logical :: vary_shift_from_proje = .false.
    ! Initial shift, needed in DMQMC to reset the shift at the start of each
    ! beta 
    real(p) :: initial_shift = 0.0_p
    ! Factor by which the changes in the population are damped when updating the
    ! shift.
    real(p) :: shift_damping = 0.050_dp
    ! Number of particles before which varyshift mode is turned on.
    ! [review] - JSS: remove default and force user to specify.
    real(dp) :: target_particles = 10000.0_dp
    ! The shift is updated at the end of each report loop when vary_shift is true.
    ! [review] - JSS: does it make sense for this to be an array?
    logical, allocatable :: vary_shift(:) ! (sampling_size)
end type shift_t

! [review] - JSS: please let's remove all references to walker.  I favour 'particle'.
! [review] - JSS: also needs to be split further into input-data, calculation-state data.
! [review] - NSB: I'm happy with any name for it, so long as we're consistent.
! [review] - NSB: Happy to go with 'particle'.
type walker_t
    ! Array sizes
    ! If these are < 0, then the values represent the number of MB to be used to
    ! store the main walker and spawned walker data respectively.
    integer :: walker_length
    ! Current number of walkers stored in the main list (processor dependent).
    ! This is updated during annihilation and merging of the spawned walkers into
    ! the main list.
    ! [review] - FDM: rename (ndets perhaps)? Should this be here?
    ! [review] - NSB: I think James, Alex and I agreed on ndets_active.
    ! [review] - JSS: Perhaps nstates_active so it applies to CCMC, DMQMC and FCIQMC?
    ! [review] - NSB: Sure.
    integer :: tot_walkers
    ! Total number of particles on all walkers/determinants (processor dependent)
    ! Updated during death and annihilation and merging.
    ! The first element is the number of normal (Hamiltonian) particles.
    ! Subsequent elements are the number of Hellmann--Feynamnn particles.
    real(dp), allocatable :: nparticles(:) ! (sampling_size)
    ! Total number of particles across *all* processors, i.e. \sum_{proc} nparticles_{proc}
    real(dp), allocatable, target :: tot_nparticles(:) ! (sampling_size)
    ! Total number of particles on all determinants for each processor
    ! [todo] - JSS: check type with Nick when merging due to the reals work.
    real(dp), allocatable :: nparticles_proc(:,:) ! (sampling_size,nprocs)
    ! Walker information: main list.
    ! sampling_size is one for each quantity sampled (i.e. 1 for standard
    ! FCIQMC/initiator-FCIQMC, 2 for FCIQMC+Hellmann--Feynman sampling).
    integer :: sampling_size
    ! number of additional elements stored for each determinant in walker_data for
    ! (e.g.) importance sampling.
    integer :: info_size
    ! a) determinants
    integer(i0), allocatable, target :: walker_dets(:,:) ! (string_len, walker_length)
    ! [review] - JSS: I would like to see a population type, which contains the
    ! [review] - JSS: encoding/decoding information (perhaps as parameters?)
    ! [review] - JSS: should we have a derived type for a single population and for an
    ! [review] - JSS: array of populations?
    ! [review] - NSB: Perhaps, though might it be slow to extract every population
    ! [review] - NSB: from the array derived type to another derived type? Is this
    ! [review] - NSB: kind of thing you're suggesting.
    ! [review] - NSB: I think that encoding info should be parameters, but at the
    ! [review] - NSB: same time it seems odd having a parameter as a type component.
    ! b) walker population
    ! NOTE:
    !   When using the real_amplitudes option, walker_population stores encoded
    !   representations of the true walker populations. To convert
    !   walker_population(:,i) to the actual population on determinant i, one must
    !   take real(walker_population(:,i),dp)/real_factor. Thus, the resolution
    !   in the true walker populations is 1/real_factor. This is how
    !   non-integers populations are implemented. When not using the real_amplitudes
    !   option, real_factor will be equal to 1, allowing only integer
    !   populations. In general, when one sees that a integer is of kind int_p, it
    !   should be understood that it stores a population in its encoded form.
    integer(int_p), allocatable, target :: walker_population(:,:) ! (sampling_size,walker_length)
    ! c) Walker information.  This contains:
    ! * Diagonal matrix elements, K_ii.  Storing them avoids recalculation.
    !   K_ii = < D_i | H | D_i > - E_0, where E_0 = <D_0 | H | D_0> and |D_0> is the
    !   reference determinant.  Always the first element.
    ! * Diagonal matrix elements for Hellmann--Feynmann sampling in 2:sampling_size
    !   elements.
    ! * Further data in sampling_size+1:sampling_size:info_size.  For example, when
    !   calculating the projected energy with various trial wavefunctions, it is
    !   useful to store quantites which are expensive to calculate and which are
    !   instead of recalculating them. For the Neel singlet state, the first component
    !   gives the total number of spins up on the first sublattice. The second
    !   component gives the number of 0-1 bonds where the 1 is on the first
    !   sublattice.
    real(p), allocatable, target :: walker_data(:,:) ! (sampling_size+info_size,walker_length)
    ! Real amplitudes can be any multiple of 2**(-real_bit_shift). They are
    ! encoded as integers by multiplying them by 2**(real_bit_shift).
    integer :: real_bit_shift
    ! real_factor = 2**(real_bit_shift)
    integer(int_p) :: real_factor
    ! The minimum amplitude of a spawning event which can be added to
    ! the spawned list.
    ! If real amplitudes are not used then the following default will be
    ! overwritten by 0.0_p. In this case it will effectively not be used and all
    ! spawnings events will be integers.
    ! [review] - NSB: This should probably be in spawned_walker_t
    real(p) :: spawn_cutoff = 0.01_p
end type walker_t

! [review] - FDM: Should the spawned walker arrays be members of the walker_t.
! [review] - JSS: I would say not as we often want to consider one or other and not
! [review] - JSS: both at the same time.
type spawned_walker_t
    ! Array sizes
    ! If these are < 0, then the values represent the number of MB to be used to
    ! store the main walker and spawned walker data respectively.
    integer :: spawned_walker_length
    ! Walker information: spawned list.
    type(spawn_t) :: qmc_spawn
    ! Walker information: received list for non-blocking communications.
    type(spawn_t) :: received_list
    ! spawn times of the progeny (only used for ct_fciqmc)
    ! [review] - JSS: fine to delete as ct_fciqmc is being rewritten...
    real(p), allocatable :: spawn_times(:) ! (spawned_walker_length)
    ! [review] - FDM: Should this be here? maybe calc?
    ! [review] - NSB: I'm not sure about this. I think it should probably be here,
    ! [review] - NSB: as in theory you could have different spawned lists with
    ! [review] - NSB: different spawning rates, so it is a property of this instance.
    ! [review] - JSS: definitely a property of the spawned object.
    ! Rate of spawning.  This is a running total over MC cycles on each processor
    ! until it is summed over processors and averaged over cycles in
    ! update_energy_estimators.
    real(p) :: rspawn
end type spawned_walker_t

! [review] - JSS: split into info about state of calculation and info arising from the
! [review] - JSS: state (ie energy estimators)?
! [review] - NSB: Sure. I wonder if there really needs to be a type containing all of
! [review] - NSB: dmqmc_t, ccmc_t, folded_spect_t, etc... Do these things ever need
! [review] - NSB: to be grouped together?
! [review] - FDM: Probably not, I was thinking that it might be nice (so that it
! [review] - FDM: can be passed to functions easily) to have one type containing the
! [review] - FDM: population information and the method specific data..
type qmc_data_t
    ! number of monte carlo cycles/report loop
    integer :: ncycles
    ! number of report cycles
    ! the shift is updated and the calculation information printed out
    ! at the end of each report cycle.
    integer :: nreport
    ! For DMQMC, beta_loops specifies the number of times
    ! the program will loop over each value of beta in the main loop.
    integer :: beta_loops = 100
    ! timestep
    real(p) :: tau
    ! projected energy
    ! This stores during an FCIQMC report loop
    !   \sum_{i/=0} <D_0|H|D_i> N_i
    ! where D_0 is the reference determinants and N_i is the walker population on
    ! determinant D_i.
    ! The projected energy is given as
    !   <D_0|H|D_0> + \sum_{i/=0} <D_0|H|D_i> N_i/N_0
    ! and so proj_energy must be 'normalised' and averaged over the report loops
    ! accordingly.
    real(p) :: proj_energy
    type(shift_t) :: shift
    type(walker_t) :: walkers
    type(reference_t) :: reference
    type(dmqmc_t) :: dmqmc
    type(initiator_t) :: initiator
    type(ccmc_t) :: ccmc
    type(folded_spect_t) folded
end type qmc_data_t
