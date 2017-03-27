program threedfinite


    implicit none
    
    real              :: u_xx, u_yy, u_zz, diagx, diagy, diagz, weightx, weighty, weightz
    real              :: delt, time, k0, hx, hy, hz
    real, allocatable :: T0(:,:,:), T(:,:,:)
    integer           :: N, i, j, k, p, u, size_x, size_y, size_z, o


    N = 25

    k0 = 1.

    size_x = N
    size_y = N
    size_z = N

    hx = 1. / (size_x + 2)
    hy = 1. / (size_y + 2)
    hz = 1. / (size_z + 2)

    delt = 0.125 * (min(hx,hy,hz)**3)/k0
    
    !allocate mesh
    allocate(T(0:size_x+1, 0:size_y+1, 0:size_z+1))
    allocate(T0(0:size_x+1, 0:size_y+1, 0:size_z+1))

    t = 0.
    t0 = 37.
    t0(:,:,0) = 0.  ! bottom face
    t0(:,0,:) = 0. ! front face
    t0(:,N+1,:) = 0.  ! back face
    t0(N+1,:,:) = 0.  ! side face
    t0(0,:,:) = 0.    ! side face
    t0(:,:,N+1) = 0.  ! top face 

   inquire(iolength=i)t0

   open(newunit=u,file='init.dat',access='direct',status='REPLACE',form='unformatted',&
   recl=i)
   write(u,rec=1) t0
   close(u)


    diagx = -2. + hx*hx/(3.*k0*delt)
    diagy = -2. + hy*hy/(3.*k0*delt)
    diagz = -2. + hz*hz/(3.*k0*delt)

    weightx = k0*delt/(hx*hx)
    weighty = k0*delt/(hy*hy)
    weightz = k0*delt/(hz*hz)

    o = int(0.1/delt)

    do p = 1, o
        write(*,FMT="(A1,A,t21,F6.2,A)",ADVANCE="NO") achar(13), &
 & " Percent Complete: ", (real(p)/real(o))*100.0, "%"
        do k = 1, size_z
            do i = 1, size_x
                do j = 1,size_y
                    u_xx = (t0(i+1, j,   k)   - 2.*t0(i,j,k) + t0(i-1, j,   k))/hx**2
                    u_yy = (t0(i,   j+1, k)   - 2.*t0(i,j,k) + t0(i,   j-1, k)) /hy**2
                    u_zz = (t0(i,   j,   k+1) - 2.*t0(i,j,k) + t0(i,   j,   k-1))/hz**2
                    t0(i,j,k) = t0(i,j,k) + k0*delt*(u_xx + u_yy + u_zz)
                end do
            end do
        end do
    time = time + delt
    end do
    print*,
    print*,time,p

   inquire(iolength=i)t0

   open(newunit=u,file='temperature.dat',access='direct',status='REPLACE',form='unformatted',&
   recl=i)
   write(u,rec=1) t0
   close(u)

end program threedfinite