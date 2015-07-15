!cfile body_particles_to_continuity.f90
!************************************************************************************
!                             S P H E R A 6.0.0
!
!                      Smoothed Particle Hydrodynamics Code
!
!************************************************************************************
!
! Module name: body_particles_to_continuity
!
! Creation: Amicarelli-Agate 13nov12
!
!************************************************************************************
! Module purpose : contributions of body particles to the continuity equation
!
! Calling routines: inter_EqCont_3D,inter_EqCont_2D
!
! Called subroutines: /
!
!************************************************************************************

  subroutine body_particles_to_continuity

! Assigning modules
  use GLOBAL_MODULE
  use AdM_USER_TYPE
  use ALLOC_MODULE
!AA501btest
  use files_entities  

! Declarations
  implicit none
  integer(4) :: npi,j,npartint,npj,k
  double precision :: temp_dden,aux,dis,dis_min,x_min,x_max,y_min,y_max,z_min,z_max,mod_normal,W_vol,sum_W_vol
  double precision :: dvar(3),aux_vec(3),aux_nor(3),aux_vec2(3)
  double precision, external :: w  

! Statements

! Loop over the body particles (maybe in parallel with a crticial section)
!omp parallel do default(none) &
!omp private(npi,j,npartint,npj,dvar,temp_dden) &
!omp shared(n_body_part,nPartIntorno_bp_f,NMAXPARTJ,PartIntorno_bp_f,bp_arr,pg,KerDer_bp_f_cub_spl,rag_bp_f) &
  do npi=1,n_body_part
  
    bp_arr(npi)%vel_mir=0.
    sum_W_vol = 0.
  
! Loop over fluid particles (contributions to fluid particles, discretized semi-analytic approach: mirror particle technique) 
     do j=1,nPartIntorno_bp_f(npi)
        npartint = (npi-1)* NMAXPARTJ + j
        npj = PartIntorno_bp_f(npartint)
! Continuity equation
! Normal for uSA
        dis_min = 999999999.
!AA501btest start        
        x_min = min(bp_arr(npi)%pos(1),pg(npj)%coord(1))
        x_max = max(bp_arr(npi)%pos(1),pg(npj)%coord(1))
        y_min = min(bp_arr(npi)%pos(2),pg(npj)%coord(2))
        y_max = max(bp_arr(npi)%pos(2),pg(npj)%coord(2))
        z_min = min(bp_arr(npi)%pos(3),pg(npj)%coord(3))
        z_max = max(bp_arr(npi)%pos(3),pg(npj)%coord(3))
!AA501btest end
        aux_nor = 0.
        do k=1,n_body_part
           if (bp_arr(k)%body==bp_arr(npi)%body) then
              aux=dot_product(rag_bp_f(:,npartint),bp_arr(k)%normal)
              if (aux>0.) then
                 if (npi==k) then
                    aux_nor(:) = bp_arr(k)%normal(:)
                    exit
                    else
                       if ( (bp_arr(k)%pos(1)>=x_min) .and. (bp_arr(k)%pos(1)<=x_max) .and. &
                            (bp_arr(k)%pos(2)>=y_min) .and. (bp_arr(k)%pos(2)<=y_max) .and. &
                            (bp_arr(k)%pos(3)>=z_min) .and. (bp_arr(k)%pos(3)<=z_max) ) then
                          call distance_point_line_3D(bp_arr(k)%pos,bp_arr(npi)%pos,pg(npj)%coord,dis)
                          dis_min =min(dis_min,dis)
                          if (dis==dis_min) aux_nor(:) = bp_arr(k)%normal(:)
                       endif
                 endif
              endif
           endif
        end do
        
! In case the normal is not yet defined the normal vector is that of the body particle (at the body surface), 
!    which is closest to the fluid particle
!AA501btest start
        mod_normal = dsqrt(dot_product(aux_nor,aux_nor))
        if (mod_normal==0.) then
           dis_min = 999999999.
           do k=1,n_body_part
              mod_normal=dot_product(bp_arr(k)%normal,bp_arr(k)%normal)
              if (mod_normal>0.) then
                 aux_vec(:) = bp_arr(k)%pos(:) - pg(npj)%coord(:) 
                 dis = dsqrt(dot_product(aux_vec,aux_vec))
                 dis_min =min(dis_min,dis)
                 if (dis==dis_min) aux_nor(:) = bp_arr(k)%normal(:)
              endif
           enddo
        endif

! relative velocity for continuity equation     
        aux_vec2(:) = bp_arr(npi)%vel(:) - pg(npj)%vel(:)
        dvar(:) = aux_nor(:)*2.*dot_product(aux_vec2,aux_nor)
        dis = dsqrt(dot_product(rag_bp_f(:,npartint),rag_bp_f(:,npartint)))
        W_vol = w(dis,Domain%h,Domain%coefke) * (pg(npj)%mass/pg(npj)%dens)
        bp_arr(npi)%vel_mir(:) = bp_arr(npi)%vel_mir(:) + (dvar(:)+pg(npj)%vel(:)) * W_vol
        sum_W_vol = sum_W_vol + W_vol            
       
! Contributions to continuity equations       
        temp_dden = pg(npj)%mass/(dx_dxbodies**ncord) * KerDer_bp_f_cub_spl(npartint) * &
                   ( dvar(1)*(-rag_bp_f(1,npartint)) + dvar(2)*(-rag_bp_f(2,npartint)) + dvar(3)*(-rag_bp_f(3,npartint)) )
        pg(npj)%dden = pg(npj)%dden - temp_dden
     
     end do

     if (sum_W_vol > 0.)   bp_arr(npi)%vel_mir(:) = bp_arr(npi)%vel_mir(:) / sum_W_vol     

  end do
!omp end parallel do
 
  return
  end subroutine body_particles_to_continuity
!---split

