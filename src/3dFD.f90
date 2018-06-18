Module Heat

    implicit none

    real    :: pulseCount, repetitionCount, time, laserOn
    real    :: dx, dy, dz, eta
    real, allocatable :: coeff(:,:,:), rx(:,:,:), ry(:,:,:), rz(:,:,:), gammaz(:,:), betaz(:,:)
    logical :: laser_flag

    private
    public :: heat_sim_3D, pulseCount, repetitionCount, laserOn, laser_flag, time, initThermalCoeff
    public :: coeff, dx, dy, dz, rx, ry, rz, gammaz, betaz, eta

    contains

subroutine heat_sim_3D(jmean, temp, tissue, numpoints, id, numproc, new_comm, right, left, counter)

        use mpi_f08
        use utils,     only : str
        use constants, only : fileplace, nxg, nyg, nzg
        use thermalConstants, only : skinDensity, skinThermalCond, skinHeatCap, tempAir4, skinBeta, skinAlpha

        implicit none
        
        real,           intent(IN)    :: jmean(:,:,:)
        integer,        intent(IN)    :: numpoints, right, left, id, numproc,counter
        type(mpi_comm), intent(IN)    :: new_comm
        real,           intent(INOUT) :: temp(0:numpoints+1,0:numpoints+1,0:numpoints+1), tissue(:,:,:)

        type(MPI_Status) :: recv_status

        !heat variables
        real              :: u_xx, u_yy, u_zz, delt, alpha
        real              :: pulselength, repetitionRate_1
        real              :: tim_fin, tim_srt, Q_vapor, L_w, mass_voxel
        real, allocatable :: T0(:,:,:), jtmp(:,:,:), Ttmp(:,:,:)
        integer           :: i, j, k, p, u, size_x, size_y, size_z, xi, yi, zi, xf, yf, zf, lo, N, o, tag,zsta,zfin

        if(id == 0)then
            !do decomp
            if(mod(numpoints,numproc) /= 0)then
                print('(I2.1,a,I2.1)'),numpoints,' not divisable by : ', numproc
                call mpi_finalize()
                error stop
            else
                N = numpoints / numproc
            end if
        end if
        tag = 1
        !send N to all processes
        call MPI_Bcast(N, 1, MPI_integer ,0 , new_comm)

        !init grid
        size_x = numpoints
        size_y = numpoints
        size_z = N

        xi = 1 
        xf = size_x

        yi = 1
        yf = size_y

        zi = 1
        zf = size_z

        call setupThermalCoeff(temp, numpoints, numproc, id)

        !allocate mesh
        allocate(T0(0:numpoints+1, 0:numpoints+1, zi-1:zf+1))
        allocate(Ttmp(numpoints, numpoints, zi:zf))
        allocate(jtmp(numpoints, numpoints, zi:zf))
        t0 = 0.

        !split temp up over all processes
        if(id == 0)then
            do i = 1, numproc-1
                zsta = (i)*zf
                zfin = zsta + zf + 1
                call mpi_send(temp(:,:,zsta:zfin), size(temp(:,:,zsta:zfin)), mpi_double_precision, i, tag, new_comm)
            end do
            t0(:,:,:) = temp(:,:,0:zf+1) 
        else
            call mpi_recv(t0, size(t0), mpi_double_precision, 0, tag, new_comm, recv_status)
        end if

        delt = dx**2/(6.*skinAlpha*skinBeta)
        delt = delt / 100.


        jtmp = 0.
        call mpi_scatter(jmean, size(jmean(:,:,zi:zf)), mpi_double_precision, jtmp(:,:,zi:zf), size(jtmp(:,:,zi:zf)), &
                         mpi_double_precision, 0, new_comm)

        ! call mpi_scatter(tissue, size(tissue(:,:,zi:zf)), mpi_double_precision, Ttmp, size(Ttmp(:,:,zi:zf)), &
        !                  mpi_double_precision, 0, new_comm)

        pulselength = 200d-3
        repetitionRate_1 = 1.d0/1.d0

        if(pulselength < delt)then
            if(id == 0)print*,"pulselength smaller than timestep, adjusting..."
            delt = pulselength / 2.
        end if

        if(id == 0)print"(a,L)","Laser On: ",laser_flag
        o = int(1./delt)
        lo = o / 100
        if(id == 0)print"(a,F9.5,1x,a,I4)","Elapsed Time: ",time, "Loops left: ",int(0.3/(100.*delt)) - counter
        call cpu_time(tim_srt)
        do p = 1, 100
            
            if(mod(p, 10) == 0 .and. id == 0) print*,p!,"*************MAX*************",maxval(temp)-273.!write(*,FMT="(A8,t21)",advance='no') achar(13)//str(real(p)/real(o)*100., 5)//' %'

            do k = zi, zf
                do j = yi, yf
                    do i = xi, xf
                        if(k == zf .and. id == numproc-1)then!B.Cs
                        u_zz = (1.-2.*rz(i,j,k)*betaz(i,j)) * t0(i,j,k) + (2. *rz (i,j,k+1)* t0(i,j,k+1)) + &
                               (2. * rz(i,j,k) * gammaz(i,j)) - 2.*rz(i,j,k)*eta*betaz(i,j)*(t0(i,j,k)**4-tempAir4)
                        else
                            u_zz = rz(i,j,k-1)*t0(i, j,     k - 1) + (1.-2.*rz(i,j,k)) * t0(i, j, k) + rz(i,j,k+1)*t0(i, j, k + 1)
                        end if
                        u_yy = ry(i,j-1,k)*t0(i, j - 1, k    ) + (1.-2.*ry(i,j,k)) * t0(i, j, k) + ry(i,j+1,k)*t0(i, j + 1, k)
                        u_xx = rx(i-1,j,k)*t0(i - 1, j, k    ) + (1.-2.*rx(i,j,k)) * t0(i, j, k) + rx(i+1,j,k)*t0(i + 1, j, k)
                        t0(i,j,k) = (u_xx + u_yy + u_zz)/3. + laserOn*coeff(i,j,k)*jtmp(i,j,k)
                    end do
                end do
            end do

            !send_recv data to right
            call MPI_Sendrecv(t0(:,:,zf), size(t0(:,:,zf)), mpi_double_precision, right, tag, &
                              t0(:,:,zf+1), size(t0(:,:,zf+1)), mpi_double_precision, right, tag, &
                              new_comm, recv_status)
            
            !send_recv data to left
            call MPI_Sendrecv(t0(:,:,zi), size(t0(:,:,zi)), mpi_double_precision, left, tag, &
                              t0(:,:,zi-1), size(t0(:,:,zi-1)), mpi_double_precision, left, tag, &
                              new_comm, recv_status)

            if(pulseCount >= pulseLength .and. laser_flag)then!turn laser off
                laser_flag = .false.
                laserOn = 0.
                pulseCount = 0.
                ! print*,"*************LASER OFF*************"
            elseif((repetitionCount >= repetitionRate_1) .and. (.not.laser_flag))then
                laser_flag = .true.
                laserOn = 1.
                pulseCount = 0.
                repetitionCount = 0.
            end if
            pulseCount = pulseCount + delt
            repetitionCount = repetitionCount + delt
            time = time + delt
        end do

        call mpi_gather(t0(:,:,zi:zf), size(t0(:,:,zi:zf)), mpi_double_precision, &
                        temp(:,:,zi:zf), size(temp(:,:,zi:zf)), mpi_double_precision, 0, new_comm)

        call Arrhenius(temp(1:numpoints,1:numpoints,1:numpoints), time, tissue, zi, zf, numpoints)

        ! call mpi_gather(Ttmp, size(Ttmp), mpi_double_precision, &
        !                 tissue(:,:,zi:zf), size(tissue(:,:,zi:zf)), mpi_double_precision,0, new_comm)

        !send data to master process and do I/O
        if(id == 0)then
            open(newunit=u,file=trim(fileplace)//'deposit/temp-'//str(counter)//"-"//str(time,5)//'.dat',access='stream', &
                 form='unformatted',status='replace')
            write(u)temp(1:numpoints,1:numpoints,1:numpoints) - 273.
            close(u)
        end if
        ! deallocate(t0, jtmp)
   end subroutine heat_sim_3D


    subroutine initThermalCoeff(delt, numpoints)

        use thermalConstants
        use constants, only : nxg, nyg, nzg

        implicit none

        real,    intent(IN) :: delt
        integer, intent(IN) :: numpoints

        real :: alpha

        dx = 2.d0 * .55d-2 / (numpoints + 2)
        dy = 2.d0 * .55d-2 / (numpoints + 2)
        dz = 2.d0 * .55d-2 / (numpoints + 2)  

        skinBeta = 1.d0 + (dz*h/skinThermalCond)

        eta = eps*S_B_Constant*dx*dy

        allocate(coeff(0:nxg+1,0:nyg+1,0:nzg+1))
        allocate(rx(0:nxg+1,0:nyg+1,0:nzg+1), ry(0:nxg+1,0:nyg+1,0:nzg+1), rz(0:nxg+1,0:nyg+1,0:nzg+1))
        allocate(gammaz(nxg, nyg), betaz(nxg, nyg), )

        coeff = 0.
        coeff(1:nxg,1:nyg,1:nzg) = skinAlpha * delt/skinThermalCond

        rx = skinAlpha * delt/(dx**2)
        ry = skinAlpha * delt/(dy**2)
        rz = skinAlpha * delt/(dz**2)

        betaz = 1. + (dz*h/skinThermalCond)
        gammaz = dz*h*tempAir/skinThermalCond

        alpha = airThermalCond(25.) / (airDensity(25.) *  airHeatCap)

        rx(:,:,nzg+1) = alpha * delt/(dx**2)
        ry(:,:,nzg+1) = alpha * delt/(dy**2)
        rz(:,:,nzg+1) = alpha * delt/(dz**2)

    end subroutine initThermalCoeff


    subroutine setupThermalCoeff(temp, numpoints, numproc, id)

        use constants, only : nxg, nyg, nzg
        use iarray, only : rhokap
        use thermalConstants

        implicit none

        integer, intent(IN) :: id, numpoints, numproc
        real,    intent(IN) :: temp(0:numpoints+1, 0:numpoints+1, 0:numpoints+1)

        integer :: i, j, k
        real    :: alphaAir, delt, kappa

        do k = 1, nzg
            do j = 1, nyg
                do i = 1, nxg
                    if(rhokap(i,j,k) <= 0.)then
                        kappa = airThermalCond(temp(i,j,k))
                        ! alpha = kappa / (rho * c_heat)
                        alphaAir = kappa / (airDensity(temp(i,j,k)) * airHeatCap)
                        ! rn = alpha * delt/(dn**2)
                        rx(i,j,k) = alphaAir * delt / (dx**2) 
                        ry(i,j,k) = alphaAir * delt / (dy**2)
                        rz(i,j,k) = alphaAir * delt / (dz**2)
                        coeff(i,j,k) = alphaAir*delt/ kappa 
                    end if
                end do
            end do
        end do

        if(id == numproc-1)then
            do j = 1, nyg
                do i = 1, nxg
                    kappa = airThermalCond(temp(i,j,k))
                    betaz(i, j)  = 1. + (dz*h/kappa)
                    gammaz(i, j) = (dz*h*tempAir)/kappa
                end do
            end do
        end if

    end subroutine setupThermalCoeff


    subroutine Arrhenius(temp, delt, tissue, zi, zf, numpoints)

        implicit none

        integer, intent(IN)    :: zi,zf, numpoints
        real,    intent(IN)    :: temp(:,:,:), delt
        real,    intent(INOUT) :: tissue(:,:,:)

        ! double precision :: a, g, r
        integer          :: i,j,k

        ! a = 3.1d91!2.9e27
        ! g = 6.28e5!2.4e5
        ! r = 8.314

        do k = 1, size(temp,3)
            do j = 1, size(temp,2)
                do i = 1, size(temp,1)
                    if(temp(i,j,k) >= 600.+273. .and. temp(i,j,k) < 700.+273 .and. tissue(i,j,k) < 6)then
                        tissue(i,j,k) = 6.!tissue + time*A*exp(-G/(R*(temp+273.)))
                    elseif(temp(i,j,k) >= 500.+273. .and. temp(i,j,k) < 600.+273 .and. tissue(i,j,k) < 5)then
                        tissue(i,j,k) = 5.
                    elseif(temp(i,j,k) >= 400.+273. .and. temp(i,j,k) < 500.+273 .and. tissue(i,j,k) < 4)then
                        tissue(i,j,k) = 4.
                    elseif(temp(i,j,k) >= 300.+273. .and. temp(i,j,k) < 400.+273 .and. tissue(i,j,k) < 3)then
                        tissue(i,j,k) = 3.
                    elseif(temp(i,j,k) >= 200.+273. .and. temp(i,j,k) < 300.+273 .and. tissue(i,j,k) < 2)then
                        tissue(i,j,k) = 2.
                    elseif(temp(i,j,k) >= 100+273 .and. temp(i,j,k) < 200.+273 .and. tissue(i,j,k) < 1)then
                        tissue(i,j,k) = 1.
                    elseif(temp(i,j,k) >= 44+273 .and. temp(i,j,k) < 100+273 .and. tissue(i,j,k) < 1)then
                        tissue(i,j,k) = 0.
                    end if
                end do
            end do
        end do
        ! do z = zi, zf
        !     do y = 1, numpoints
        !         do x = 1, numpoints
        !             if(temp(x, y, z) >= 44)then
        !                 tissue(x, y, z) = tissue(x, y, z) + delt*A*exp(-G/(R*(temp(x,y,z)+273)))
        !             end if
        !         end do
        !     end do
        ! end do

    end subroutine  Arrhenius
end Module Heat