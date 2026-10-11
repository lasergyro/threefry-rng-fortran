! Known-answer check of threefry2x32
!
! Build and run from tests/ (the vector file is opened by relative path):
!   gfortran -O2 ../src/threefry_mod.f90 threefry_kat_test.f90 -o threefry_kat_test && ./threefry_kat_test

program kat_test
  use threefry_mod, only: i8, threefry2x32,threefry2x32_r, tf_rounds
  implicit none
  integer :: u, ios, nr, nread, nfail
  character(len=512) :: line
  character(len=16) :: nm
  character(len=8) :: h(6)
  integer(kind=i8) :: v(6), o0, o1

  nread = 0; nfail = 0
  open(newunit=u, file='threefry_kat_vectors.txt', status='old', action='read')
  do
    read(u, '(a)', iostat=ios) line
    if (ios /= 0) exit
    if (line(1:13) /= 'threefry2x32 ') cycle
    read(line, *) nm, nr, h
    read(h, '(z8)') v
    nread = nread + 1

    call threefry2x32_r(v(1), v(2), v(3), v(4),nr, o0, o1)
    if (o0 /= v(5) .or. o1 /= v(6)) then
      nfail = nfail + 1
      write(*, '(a,2(1x,z8.8),a,2(1x,z8.8))') 'FAIL got from threefry2x32_r', o0, o1, ', expected', v(5), v(6)
    end if

    if (nr == tf_rounds) then
      call threefry2x32(v(1), v(2), v(3), v(4), o0, o1)
      if (o0 /= v(5) .or. o1 /= v(6)) then
        nfail = nfail + 1
        write(*, '(a,2(1x,z8.8),a,2(1x,z8.8))') 'FAIL got from threefry2x32', o0, o1, ', expected', v(5), v(6)
      end if
    end if
  end do
  close(u)

  write(*, '(a,i0,a,i0,a)') 'threefry2x32(_r) known-answer check: ', nread, &
    ' vectors, ', nfail, ' failed'
  if (nread /= 9 .or. nfail /= 0) stop 1
end program kat_test
