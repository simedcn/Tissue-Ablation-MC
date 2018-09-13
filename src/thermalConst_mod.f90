module thermalConstants

    implicit none

    real, parameter :: skinThermalCond=0.209d0, skinDensity=1070.d0, skinHeatCap=3400.d0
    real, parameter :: airHeatCap=1.006d3, tempAir=25.d0+273.d0, tempAir4=tempAir**4
    real, parameter :: h=10.d0, eps=0.98d0,lw=2256.d3
    real, parameter :: skinAlpha=skinThermalCond/(skinDensity * skinHeatCap)
    real, parameter :: waterContentInit=.75, proteinContent=1.d0-waterContentInit!%
    real            :: skinDensityInit, QVapor

    !skinDensity    : 1020 Kg/m3    source 10.1109/TBME.2009.2033464  burn papers says: 1093-1190
    !skinThermalCond: 0.21 W/m K    source burn paper- pig skin
    !skinHeatCap    : 3349 J/Kg K   source burn paper- pig skin

    !carbon source mackenzie 1986

    !airHeatCap: J/kg K  source engineeringtoolbox.com 

    !lw: J/kg latent heat of vaporisation water

    ! h: convective constant W/m2 K  between 2-10                   ************need source************
    ! eps: emissivity                           ************need source************

    contains

        real function airThermalCond(T, i)
        !data taken from engineeringtoolbox.com and fitted in gnuplot
        !temp input in kelvin
            implicit none

            real, intent(IN) :: T!in Kelvin
            real, parameter  :: a=-0.188521, b=0.000367259, c=0.212453
            integer :: i

            if(t < 0.)then
                print*,i,'loop #'
                error stop "Negative temp in kelvin"
            end if
            airThermalCond = 31.62d-3!a * exp(-b * (T - 273.15d0)) + c
        end function airThermalCond


        real function airDensity(T)
        !values taken from wikipedia
        !temp input in kelvin
            implicit none

            real, intent(IN) :: T !in kelvin
            real, parameter  :: pressue1ATM=101.325d3, Rspec=287.058d0

            airDensity = pressue1ATM / (Rspec * T)

        end function airDensity


        elemental real function getWaterContent(Qcurrent)

            implicit none

            real, intent(IN) :: Qcurrent

            getWaterContent = max(min(waterContentInit - waterContentInit * (Qcurrent / QVapor), waterContentInit), 0.0)

        end function getWaterContent


        !source for three below function: Analysis of Thermal Relaxation During LaserIrradiation of Tissue, Choi & Welch 2001
        real function getSkinDensity(waterContent)
        !get dsensity of skin based upon water content. In Kg m-3

            implicit none

            real, intent(IN) :: waterContent

            getSkinDensity = 100.d0 / (waterContent + 0.649d0*proteinContent) !new function with protein
            !getSkinDensity = 1.d0 / (6.16d-5 * waterContent + 9.38d-4) !! linear function
            ! getSkinDensity = 1070d0 / (1 + exp(10*(waterContent - 0.5)))**(1.d0/74.d0) !!logistic funtion
            ! getSkinDensity = 3.489 * exp(-6.d0 * (waterContent - .5)) + 1000.d0 !!exponetial function

        end function getSkinDensity


        real function getSkinHeatCap(waterContent)
        !get heat capacity for skin. In J Kg-1 K-1 

            implicit none

            real, intent(IN) :: waterContent

            getSkinHeatCap = 100.d0*(4.2*waterContent + 1.09d0*proteinContent) !new function with protein
            !getSkinHeatCap = 2.5d3 * waterContent + 1.7d3

        end function getSkinHeatCap


        real function getSkinThermalCond(waterContent, currentDensity)
        !get thermal conductivity for skin. In W m-1 K-1 

            implicit none

            real, intent(IN) :: waterContent, currentDensity

            getSkinThermalCond = currentDensity * (6.28d-4*waterContent + 1.17d-4*proteinContent)!new function with protein
            !getSkinThermalCond = currentDensity*1.d-3 * (.454 * waterContent + 0.174d0)

        end function getSkinThermalCond
end module thermalConstants

        !init heat variables for medium
        ! kappa = 0.00209 !0.0056 ! W/cm K    thermal conductivity
        ! rho = 1.07 ! g/cm^3                 density
        ! c_heat = 3.4 !J/g K                 heat capacity
        ! eps = 0.98
        ! sigma = 5.670373e-8
        ! t_air = 25.+273.
        ! t_air4 = t_air**4
        ! h = 10.
