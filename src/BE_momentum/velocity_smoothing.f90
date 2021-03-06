!-------------------------------------------------------------------------------
! SPHERA v.8.0 (Smoothed Particle Hydrodynamics research software; mesh-less
! Computational Fluid Dynamics code).
! Copyright 2005-2018 (RSE SpA -formerly ERSE SpA, formerly CESI RICERCA,
! formerly CESI-Ricerca di Sistema)
!
! SPHERA authors and email contact are provided on SPHERA documentation.
!
! This file is part of SPHERA v.8.0.
! SPHERA v.8.0 is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
! SPHERA is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
! GNU General Public License for more details.
! You should have received a copy of the GNU General Public License
! along with SPHERA. If not, see <http://www.gnu.org/licenses/>.
!-------------------------------------------------------------------------------
!-------------------------------------------------------------------------------
! Program unit: velocity_smoothing 
! Description: To calculate a corrective term for velocity.    
!-------------------------------------------------------------------------------
subroutine velocity_smoothing
!------------------------
! Modules
!------------------------
use Static_allocation_module
use Hybrid_allocation_module
use Dynamic_allocation_module
!------------------------
! Declarations
!------------------------
implicit none
integer(4) :: npi,npj,contj,npartint,ii
double precision :: rhoi,rhoj,amassj,pesoj,moddervel
double precision,dimension(3) :: dervel 
double precision,dimension(:,:),allocatable :: dervel_mat
!------------------------
! Explicit interfaces
!------------------------
!------------------------
! Allocations
!------------------------
!------------------------
! Initializations
!------------------------
if (n_bodies>0) then  
   allocate(dervel_mat(nag,3))
   dervel_mat(:,:) = 0.d0
endif
!------------------------
! Statements
!------------------------
! Body particle contributions to pressure smoothing
if (n_bodies>0) then
   call start_and_stop(3,7)
   call start_and_stop(2,19)
   call body_to_smoothing_vel(dervel_mat)
   call start_and_stop(3,19)
   call start_and_stop(2,7)
endif
!$omp parallel do default(none)                                                &
!$omp shared(pg,Med,nPartIntorno,NMAXPARTJ,PartIntorno,PartKernel,indarrayFlu) &
!$omp shared(Array_Flu,esplosione,Domain,n_bodies,dervel_mat,ncord)            &
!$omp private(ii,npi,contj,npartint,npj,rhoi,rhoj,amassj,dervel,moddervel)     &
!$omp private(pesoj)
do ii=1,indarrayFlu
   npi = Array_Flu(ii)
   pg(npi)%var = zero
! The mixture particles, which are temporarily affected by the frictional 
! viscosity threshold are fixed.
   if (pg(npi)%mu==Med(pg(npi)%imed)%mumx) cycle
   pg(npi)%Envar = zero
   do contj=1,nPartIntorno(npi)
      npartint = (npi - 1) * NMAXPARTJ + contj
      npj = PartIntorno(npartint)
      rhoi = pg(npi)%dens
      rhoj = pg(npj)%dens
      amassj = pg(npj)%mass
      dervel(:) = pg(npj)%vel(:) - pg(npi)%vel(:)
      if (pg(npj)%vel_type/="std") then
         rhoj = rhoi
         amassj = pg(npi)%mass
         moddervel = - two * (pg(npi)%vel(1) * pg(npj)%zer(1) + pg(npi)%vel(2) &
                     * pg(npj)%zer(2) + pg(npi)%vel(3) * pg(npj)%zer(3))
         dervel(:) = moddervel * pg(npj)%zer(:)    
      endif
      if (Med(pg(npj)%imed)%den0/=Med(pg(npi)%imed)%den0) cycle
      pesoj = amassj * PartKernel(4,npartint) / rhoj
      pg(npi)%var(:) = pg(npi)%var(:) + dervel(:) * pesoj   
      if (esplosione) pg(npi)%Envar = pg(npi)%Envar + (pg(npj)%IntEn -         &
                                      pg(npi)%IntEn) * pesoj
   enddo
   if (n_bodies>0) then
      pg(npi)%var(:) = pg(npi)%var(:) + dervel_mat(npi,:)
   endif
! Impose boundary conditions at inlet and outlet sections (DB-SPH)
   if (Domain%tipo=="bsph") then
      call DBSPH_inlet_outlet(npi)
      else
         if (ncord==3) then
            call velocity_smoothing_SA_SPH_3D(npi)
            else
               call velocity_smoothing_SA_SPH_2D(npi)
         endif
   endif
enddo
!$omp end parallel do
!------------------------
! Deallocations
!------------------------
if (n_bodies>0) deallocate(dervel_mat)
return
end subroutine velocity_smoothing

