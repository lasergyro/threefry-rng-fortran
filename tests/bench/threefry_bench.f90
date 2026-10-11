! Times threefry2x32 per call, two ways:
!   latency     each call's output is the next call's counter, so calls can't
!               overlap: the cost of one isolated draw
!   throughput  independent counters, so the CPU may overlap calls
! plus threefry2x32_r at the same 20 rounds, and an empty call with the same
! interface (bench_stub below) for the cost of the call itself.
! Prints ns per call; run_bench.sh adds cycles. Every timing is the best of
! five repetitions.

module bench_stub
  use threefry_mod, only: i8
  implicit none
  private
  public :: empty2x32
contains
  subroutine empty2x32(c0,c1,k0,k1,o0,o1)
    integer(kind=i8), intent(in)  :: c0,c1,k0,k1
    integer(kind=i8), intent(out) :: o0,o1
    o0=c0+k0+1
    o1=c1+k1
  end subroutine empty2x32
end module bench_stub

program threefry_bench
  use threefry_mod, only: i8, threefry2x32, threefry2x32_r, tf_rounds
  use bench_stub, only: empty2x32
  implicit none
  integer, parameter :: r8 = kind(1.0d0)
  integer(kind=i8), parameter :: n = 20000000_i8
  integer(kind=i8) :: check

  call report('threefry2x32 latency', 1, .true.)
  call report('threefry2x32 throughput', 1, .false.)
  call report('threefry2x32_r latency', 2, .true.)
  call report('empty call latency', 3, .true.)

contains

  subroutine report(label, which, dependent)
    character(len=*), intent(in) :: label
    integer, intent(in) :: which
    logical, intent(in) :: dependent
    integer(kind=i8) :: i, c0, o0, o1
    integer(kind=i8) :: t0, t1, rate
    integer :: rep
    real(kind=r8) :: best
    best = huge(1.0_r8)
    do rep = 1, 5
      c0 = 0
      check = 0
      call system_clock(t0, rate)
      do i = 0, n-1
        if (.not. dependent) c0 = i
        select case (which)
        case (1); call threefry2x32(c0, 0_i8, 0_i8, 0_i8, o0, o1)
        case (2); call threefry2x32_r(c0, 0_i8, 0_i8, 0_i8, tf_rounds, o0, o1)
        case default; call empty2x32(c0, 0_i8, 0_i8, 0_i8, o0, o1)
        end select
        if (dependent) c0 = o0
        check = ieor(check, o1)
      end do
      call system_clock(t1)
      best = min(best, 1e9_r8*real(t1-t0,r8)/real(rate,r8)/real(n,r8))
    end do
    write(*,'(a,"|",f0.3,"|",z0)') trim(label), best, check
  end subroutine report

end program threefry_bench
