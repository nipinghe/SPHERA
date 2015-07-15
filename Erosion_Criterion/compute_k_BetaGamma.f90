!************************************************************************************
!                             S P H E R A 6.0.0
!
!                      Smoothed Particle Hydrodynamics Code
!
!************************************************************************************
!
! Module name: compute_k_BetaGamma
!
! Versions: 
! 01 Amicarelli 08Apr14 (creation)
!
!************************************************************************************
! Module purpose : (v5.04) To compute k_BetaGamma=teta_c/teta_c,0
!                  k_BetaGamma is the ratio between Shields critical non-dimensional 
!                  stress for a generic 3D slope (teta_c) and its analogous value 
!                  defined by Shields' diagram (teta_c,00) on a flat bed
!
! Calling routines: Shields
!
! Called subroutines: quadratic_equation 
!
!************************************************************************************

  subroutine compute_k_BetaGamma(npi,npj,DistZmin)

! Assigning modules
  use GLOBAL_MODULE 
  use AdM_USER_TYPE
  use ALLOC_MODULE
  use files_entities

! Declarations
  implicit none
  integer(4), intent(in) :: npi,npj
  double precision,intent(in) :: DistZmin
   integer(4) :: i_cell,i_aux,i_grid,j_grid,k_grid,n_roots,test_root1,test_root2,case_test,inpj_grid,jnpj_grid
  double precision :: k_v,k_Beta0,U_inf,Re,DELTA_Seminara,aux_var,a,b,c,root1,root2,Uf,z_aux,alfa
  double precision :: U_inf_vec(2),Uf_vec(2)
  double precision :: s_uni_vec(3),n2_uni_vec(3),vel_n(3)
  integer(4), external :: CellIndices,ParticleCellNumber
  
! Initializations
  k_v = 0.41d0  
  test_root1 = 0
  test_root2 = 0
  
! Statements
! unity vector aligned with the component of the trajectory normal to the interface
  vel_n(:) = dot_product(pg(npj)%vel_old,pg(npi)%normal_int) * pg(npi)%normal_int(:)  
  s_uni_vec(:) = pg(npj)%vel_old(:) - vel_n(:)
  s_uni_vec(:) = s_uni_vec(:)/dsqrt(dot_product(s_uni_vec,s_uni_vec)) 
! n2 is the bi-normal to the particle trajectory     
  call Vector_Product(pg(npi)%normal_int,s_uni_vec,n2_uni_vec,3)
! Beta
  if(ncord==3) then
     pg(npi)%Beta_slope = dasin(-s_uni_vec(3))
     else
        alfa = dasin(pg(npi)%normal_int(3))
        pg(npi)%Beta_slope = PIGRECO/2.d0 - alfa
        if (s_uni_vec(3)>0.d0) pg(npi)%Beta_slope = -pg(npi)%Beta_slope
  endif
! Gamma     
  pg(npi)%Gamma_slope = dasin(dabs(n2_uni_vec(3)))
  if (Granular_flows_options%Gamma_slope_flag==0) pg(npi)%Gamma_slope = 0.d0 
  if ( (pg(npi)%Beta_slope>=Med(pg(npi)%imed)%Phi) .or. (dabs(pg(npi)%Gamma_slope)>=Med(pg(npi)%imed)%Phi) ) then
! If the internal friction angle is equal or less than a slope angle (Beta or Gamma) then the granular particle is eroded
        pg(npi)%k_BetaGamma = 0.0d0
        else
! Compute k_Beta0
           k_Beta0 = dcos(pg(npi)%Beta_slope) * (1-dtan(pg(npi)%Beta_slope)/dtan(Med(pg(npi)%imed)%Phi))
           if (pg(npi)%Gamma_slope==0.d0) then
! compute k_BetaGamma=k_Beta0
              pg(npi)%k_BetaGamma = k_Beta0
              else
! Getting U_inf
                 i_cell = ParticleCellNumber(pg(npi)%coord) 
                 i_aux = CellIndices(i_cell,i_grid,j_grid,k_grid)
                 U_inf = dsqrt(dot_product(pg(npj)%vel_old,pg(npj)%vel_old)) 
! Compute Re (flow around a sphere)
                 Re = U_inf*Med(pg(npi)%imed)%D50/pg(npj)%visc 
! Compute the drag coefficient C_D (Morrison 2013)              
                 if (Re<=100.0d0) then
                    pg(npi)%C_D = 1.0d0
                    else
                       if (Re>=1.0e6) then
                          pg(npi)%C_D = 0.2d0
                          else
                             pg(npi)%C_D = 24.0d0/Re + (2.6d0*Re/5.0d0)/(1.0d0+(Re/5.0d0)**1.52d0) +  &
                                   (0.411d0*(Re/2.63e5)**(-7.94d0))/(1.0d0+(Re/2.63e5)**(-8.0d0)) + (Re**0.8d0)/4.61e5
                       endif
                 endif    
! Compute the lift coefficient C_L (our regression from data in Seminara et al. 2002 WRR)                
                 if (Re<=2000.) then
                    pg(npi)%C_L = 0.07d0
                    else
                       if (Re>=17.5e3) then
                          pg(npi)%C_L = 0.5d0
                          else
                             pg(npi)%C_L = (9.0d0*(10.0d0)**(-5.0d0))*(Re**0.882d0)
                       endif         
                 endif    
! Compute DELTA_Seminara
                 Uf = U_inf
! Compute height over fluid - bed load interface
                 z_aux = DistZmin
                 DELTA_Seminara = (4.0d0/3.0d0) * dtan(Med(pg(npi)%imed)%Phi) * (pg(npi)%C_L/pg(npi)%C_D) * (pg(npi)%u_star*Med(pg(npi)%imed)%D50)/(k_v*Uf*z_aux)   
                 if (pg(npi)%Beta_slope==0.0d0) then
! Compute k_BetaGamma=k_0Gamma
                      pg(npi)%k_BetaGamma = dcos(pg(npi)%Gamma_slope) * (dsqrt(1.0d0 - ((1.0d0-DELTA_Seminara)**2.0d0) * &
                                       (dtan(pg(npi)%Gamma_slope)/dtan(Med(pg(npi)%imed)%Phi))**2.0d0) - DELTA_Seminara) / (1-DELTA_Seminara)
                    else
! compute coefficients (a,b,c) of the quadratic equation for k_BetaGamma and solve it
                       aux_var = (dtan(pg(npi)%Beta_slope))**2.0d0 + (dtan(pg(npi)%Gamma_slope))**2.0d0
                       a = (1.0d0-DELTA_Seminara)
                       b = 2.0d0 * ( DELTA_Seminara/dsqrt(1.0d0+aux_var) + dsin(pg(npi)%Beta_slope)/dtan(Med(pg(npi)%imed)%Phi) )
                       c = (1.0d0+DELTA_Seminara) / (1.0d0+aux_var) * (-1.0d0+aux_var/(dtan(Med(pg(npi)%imed)%Phi))**2.0d0)                    
                       call quadratic_equation(a,b,c,n_roots,root1,root2)
                       if ((root1<=k_Beta0).and.(root1>=0.d0)) test_root1 = 1
                       if ((root2<=k_Beta0).and.(root2>=0.d0)) test_root2 = 1
                       case_test = n_roots * 100 + test_root1*10 + test_root2
                       select case (case_test)
                          case(211)
                                pg(npi)%k_BetaGamma = max(root1,root2)
                          case(210,110)
                             pg(npi)%k_BetaGamma = root1 
                          case(201)
                             pg(npi)%k_BetaGamma = root2
                          case(200,100,0)
                                pg(npi)%k_BetaGamma = k_Beta0   
                       end select
                    endif
          endif
    endif
  
  return
  end subroutine compute_k_BetaGamma
!---split

