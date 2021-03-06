

MODULE dynbfr
   !!==============================================================================
   !!                 ***  MODULE  dynbfr  ***
   !! Ocean dynamics :  bottom friction component of the momentum mixing trend
   !!==============================================================================
   !! History :  3.2  ! 2008-11  (A. C. Coward)  Original code
   !!            3.4  ! 2011-09  (H. Liu) Make it consistent with semi-implicit
   !!                            Bottom friction (ln_bfrimp = .true.) 
   !!----------------------------------------------------------------------

   !!----------------------------------------------------------------------
   !!   dyn_bfr      : Update the momentum trend with the bottom friction contribution
   !!----------------------------------------------------------------------
   USE oce             ! ocean dynamics and tracers variables
   USE dom_oce         ! ocean space and time domain variables 
   USE zdf_oce         ! ocean vertical physics variables
   USE zdfbfr          ! ocean bottom friction variables
   USE trdmod          ! ocean active dynamics and tracers trends 
   USE trdmod_oce      ! ocean variables trends
   USE in_out_manager  ! I/O manager
   USE prtctl          ! Print control
   USE timing          ! Timing
   USE wrk_nemo        ! Memory Allocation

   IMPLICIT NONE
   PRIVATE

   PUBLIC   dyn_bfr    !  routine called by step.F90

   !! * Substitutions
   !!----------------------------------------------------------------------
   !!                    ***  domzgr_substitute.h90   ***
   !!----------------------------------------------------------------------
   !! ** purpose :   substitute fsdep. and fse.., the vert. depth and scale
   !!      factors depending on the vertical coord. used, using CPP macro.
   !!----------------------------------------------------------------------
   !! History :  1.0  !  2005-10  (A. Beckmann, G. Madec) generalisation to all coord.
   !!            3.1  !  2009-02  (G. Madec, M. Leclair)  pure z* coordinate
   !!----------------------------------------------------------------------
! reference for s- or zps-coordinate (3D no time dependency)
! z- or s-coordinate (1D or 3D + no time dependency) use reference in all cases




   !!----------------------------------------------------------------------
   !! NEMO/OPA 3.3 , NEMO Consortium (2010)
   !! $Id: domzgr_substitute.h90 2528 2010-12-27 17:33:53Z rblod $
   !! Software governed by the CeCILL licence (NEMOGCM/NEMO_CeCILL.txt)
   !!----------------------------------------------------------------------
   !!----------------------------------------------------------------------
   !!                    *** zdfddm_substitute.h90  ***
   !!----------------------------------------------------------------------
   !! ** purpose :   substitute fsaht. the eddy diffusivity coeff.
   !!      with a constant or 1D or 2D or 3D array, using CPP macro.
   !!----------------------------------------------------------------------
!   'key_zdfddm' :                      avs: 3D array defined in zdfddm module
   !!----------------------------------------------------------------------
   !! NEMO/OPA 4.0 , NEMO Consortium (2011)
   !! $Id: zdfddm_substitute.h90 2715 2011-03-30 15:58:35Z rblod $ 
   !! Software governed by the CeCILL licence     (NEMOGCM/NEMO_CeCILL.txt)
   !!----------------------------------------------------------------------
   !!----------------------------------------------------------------------
   !!                   ***  vectopt_loop_substitute  ***
   !!----------------------------------------------------------------------
   !! ** purpose :   substitute the inner loop starting and inding indices 
   !!      to allow unrolling of do-loop using CPP macro.
   !!----------------------------------------------------------------------
   !!----------------------------------------------------------------------
   !! NEMO/OPA 3.3 , NEMO Consortium (2010)
   !! $Id: vectopt_loop_substitute.h90 2528 2010-12-27 17:33:53Z rblod $ 
   !! Software governed by the CeCILL licence (NEMOGCM/NEMO_CeCILL.txt)
   !!----------------------------------------------------------------------
   !!----------------------------------------------------------------------
   !! NEMO/OPA 3.3 , NEMO Consortium (2010)
   !! $Id: dynbfr.F90 3294 2012-01-28 16:44:18Z rblod $
   !! Software governed by the CeCILL licence     (NEMOGCM/NEMO_CeCILL.txt)
   !!----------------------------------------------------------------------
CONTAINS
   
   SUBROUTINE dyn_bfr( kt )
      !!----------------------------------------------------------------------
      !!                  ***  ROUTINE dyn_bfr  ***
      !!
      !! ** Purpose :   compute the bottom friction ocean dynamics physics.
      !!
      !! ** Action  :   (ua,va)   momentum trend increased by bottom friction trend
      !!---------------------------------------------------------------------
      INTEGER, INTENT(in) ::   kt   ! ocean time-step index
      !! 
      INTEGER  ::   ji, jj       ! dummy loop indexes
      INTEGER  ::   ikbu, ikbv   ! local integers
      REAL(wp) ::   zm1_2dt      ! local scalar
      REAL(wp), POINTER, DIMENSION(:,:,:) ::  ztrdu, ztrdv
      !!---------------------------------------------------------------------
      !
      IF( nn_timing == 1 )  CALL timing_start('dyn_bfr')
      !
      IF( .NOT.ln_bfrimp) THEN     ! only for explicit bottom friction form
                                    ! implicit bfr is implemented in dynzdf_imp

        zm1_2dt = - 1._wp / ( 2._wp * rdt )

        IF( l_trddyn )   THEN                      ! temporary save of ua and va trends
           CALL wrk_alloc( jpi,jpj,jpk, ztrdu, ztrdv )
           ztrdu(:,:,:) = ua(:,:,:)
           ztrdv(:,:,:) = va(:,:,:)
        ENDIF


        DO jj = 2, jpjm1
           DO ji = 2, jpim1
              ikbu = mbku(ji,jj)          ! deepest ocean u- & v-levels
              ikbv = mbkv(ji,jj)
              !
              ! Apply stability criteria on absolute value  : abs(bfr/e3) < 1/(2dt) => bfr/e3 > -1/(2dt)
              ua(ji,jj,ikbu) = ua(ji,jj,ikbu) + MAX(  bfrua(ji,jj) / e3u(ji,jj,ikbu) , zm1_2dt  ) * ub(ji,jj,ikbu)
              va(ji,jj,ikbv) = va(ji,jj,ikbv) + MAX(  bfrva(ji,jj) / e3v(ji,jj,ikbv) , zm1_2dt  ) * vb(ji,jj,ikbv)
           END DO
        END DO

        !
        IF( l_trddyn )   THEN                      ! save the vertical diffusive trends for further diagnostics
           ztrdu(:,:,:) = ua(:,:,:) - ztrdu(:,:,:)
           ztrdv(:,:,:) = va(:,:,:) - ztrdv(:,:,:)
           CALL trd_mod( ztrdu(:,:,:), ztrdv(:,:,:), jpdyn_trd_bfr, 'DYN', kt )
           CALL wrk_dealloc( jpi,jpj,jpk, ztrdu, ztrdv )
        ENDIF
        !                                          ! print mean trends (used for debugging)
        IF(ln_ctl)   CALL prt_ctl( tab3d_1=ua, clinfo1=' bfr  - Ua: ', mask1=umask,               &
           &                       tab3d_2=va, clinfo2=       ' Va: ', mask2=vmask, clinfo3='dyn' )
        !
      ENDIF     ! end explicit bottom friction
      !
      IF( nn_timing == 1 )  CALL timing_stop('dyn_bfr')
      !
   END SUBROUTINE dyn_bfr

   !!==============================================================================
END MODULE dynbfr
