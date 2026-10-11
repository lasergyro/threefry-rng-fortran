! Streams raw bytes from threefry2x32, for feeding external statistical test
! suites (PractRand, dieharder, TestU01) that expect a flat binary stream of
! pseudorandom 32-bit words. See run_empirical_tests.sh.
!
! The counter is a single 64-bit index split into the two 32-bit counter
! words c0 (low) and c1 (high), with a fixed zero key -- the simplest
! non-repeating stream the generator can produce, covering up to 2**64
! pairs (2**67 bytes) before it would repeat.
!
! Usage: threefry_dump <nbytes> <outfile|-> [counter|key] [nrounds]
!   'key' mode holds the counter at zero and steps the 64-bit index through
!   the key words (k0 low, k1 high) instead, testing the key schedule's
!   diffusion rather than the counter's.
!   Without nrounds, the stream comes from threefry2x32, the unrolled
!   version at tf_rounds = 20 that callers use. With nrounds, it comes from
!   threefry2x32_r at that round count, for locating the round count at
!   which the output starts failing (see find_round_threshold.sh).
!   outfile may be '-' to stream to standard output (for piping directly
!   into a consumer, e.g. `threefry_dump 34359738368 - | RNG_test stdin32`),
!   which avoids writing a large file to disk first. A consumer that closes
!   the pipe before reading all nbytes (as RNG_test does once -tlmax is
!   reached) is the expected, non-error end of the stream: the write that
!   hits the closed pipe is caught by iostat and ends the program cleanly.
!
! Each word is written as a 32-bit integer in the machine's byte order,
! which is what the consumers read (PractRand's stdin32, dieharder's raw
! input, testu01_stdin.c).

program threefry_dump
  use threefry_mod, only: threefry2x32, threefry2x32_r, i8, m32
  implicit none

  ! Pairs are generated into this buffer and flushed in one write per
  ! bufpairs pairs (8 MiB): batching the write call is what makes this
  ! ~3x faster than writing each pair as it is generated.
  integer, parameter :: i4 = selected_int_kind(9)  ! 32-bit: one output word
  integer(kind=i8), parameter :: bufpairs = 1048576_i8
  integer(kind=i4) :: buf(2*bufpairs)

  integer(kind=i8) :: nbytes, npairs, idx, c0, c1, k0, k1, o0, o1, chunk
  integer :: u, j, ios, nrounds
  character(len=4096) :: arg  ! long enough for any output path
  logical :: to_stdout, key_mode, fixed_rounds

  if (command_argument_count() < 2) then
    write(0,'(a)') 'usage: threefry_dump <nbytes> <outfile|-> [counter|key] [nrounds]'
    stop 1
  end if
  call get_command_argument(1, arg)
  read(arg,*) nbytes
  call get_command_argument(2, arg)
  to_stdout = (trim(arg) == '-')
  key_mode = .false.
  if (command_argument_count() >= 3) then
    call get_command_argument(3, arg)
    key_mode = (trim(arg) == 'key')
  end if
  fixed_rounds = (command_argument_count() < 4)
  nrounds = 0
  if (.not. fixed_rounds) then
    call get_command_argument(4, arg)
    read(arg,*) nrounds
  end if

  npairs = (nbytes + 7_i8) / 8_i8

  if (to_stdout) then
    ! gfortran refuses to change ACCESS on the preconnected unit 6, so open
    ! /dev/stdout as a fresh unit instead (Unix-only, matching the rest of
    ! this toolchain's assumptions: gfortran + a Unix shell pipeline).
    open(newunit=u, file='/dev/stdout', form='unformatted', access='stream', &
         action='write')
  else
    call get_command_argument(2, arg)
    open(newunit=u, file=trim(arg), form='unformatted', access='stream', &
         status='replace', action='write')
  end if

  idx = 0_i8
  do while (idx < npairs)
    chunk = min(bufpairs, npairs-idx)
    do j = 1, int(chunk)
      c0 = iand(idx, m32)
      c1 = iand(ishft(idx,-32), m32)
      k0 = 0_i8
      k1 = 0_i8
      if (key_mode) then
        k0 = c0
        k1 = c1
        c0 = 0_i8
        c1 = 0_i8
      end if
      if (fixed_rounds) then
        call threefry2x32(c0, c1, k0, k1, o0, o1)
      else
        call threefry2x32_r(c0, c1, k0, k1, nrounds, o0, o1)
      end if
      ! The word's value, [0,2**32), as an i4 with the same 32 bits: subtract
      ! 2**32 when bit 31 is set (as tf_rotl32 does). Copying the i8's bytes
      ! with transfer would instead take its low-addressed half, which is the
      ! high, all-zero half on a big-endian machine.
      buf(2*j-1) = int(o0 - ishft(ibits(o0,31,1),32), i4)
      buf(2*j)   = int(o1 - ishft(ibits(o1,31,1),32), i4)
      idx = idx + 1_i8
    end do
    write(u, iostat=ios) buf(1:2*int(chunk))
    if (ios /= 0) exit  ! consumer closed the pipe early; a normal stop
  end do
  close(u)

end program threefry_dump
