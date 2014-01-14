

MODULE closea
   !!======================================================================
   !!                       ***  MODULE  closea  ***
   !! Closed Seas  : specific treatments associated with closed seas
   !!======================================================================
   !! History :   8.2  !  00-05  (O. Marti)  Original code
   !!             8.5  !  02-06  (E. Durand, G. Madec)  F90
   !!             9.0  !  06-07  (G. Madec)  add clo_rnf, clo_ups, clo_bat
   !!        NEMO 3.4  !  03-12  (P.G. Fogli) sbc_clo bug fix & mpp reproducibility
   !!----------------------------------------------------------------------

   !!----------------------------------------------------------------------
   !!   dom_clo    : modification of the ocean domain for closed seas cases
   !!   sbc_clo    : Special handling of closed seas
   !!   clo_rnf    : set close sea outflows as river mouths (see sbcrnf)
   !!   clo_ups    : set mixed centered/upstream scheme in closed sea (see traadv_cen2)
   !!   clo_bat    : set to zero a field over closed sea (see domzrg)
   !!----------------------------------------------------------------------
   USE oce             ! dynamics and tracers
   USE dom_oce         ! ocean space and time domain
   USE in_out_manager  ! I/O manager
   USE sbc_oce         ! ocean surface boundary conditions
   USE lib_fortran,    ONLY: glob_sum, DDPDD
   USE lbclnk          ! lateral boundary condition - MPP exchanges
   USE lib_mpp         ! MPP library
   USE timing

   IMPLICIT NONE
   PRIVATE

   PUBLIC dom_clo      ! routine called by domain module
   PUBLIC sbc_clo      ! routine called by step module
   PUBLIC clo_rnf      ! routine called by sbcrnf module
   PUBLIC clo_ups      ! routine called in traadv_cen2(_jki) module
   PUBLIC clo_bat      ! routine called in domzgr module

   INTEGER, PUBLIC, PARAMETER          ::   jpncs   = 4      !: number of closed sea
   INTEGER, PUBLIC, DIMENSION(jpncs)   ::   ncstt            !: Type of closed sea
   INTEGER, PUBLIC, DIMENSION(jpncs)   ::   ncsi1, ncsj1     !: south-west closed sea limits (i,j)
   INTEGER, PUBLIC, DIMENSION(jpncs)   ::   ncsi2, ncsj2     !: north-east closed sea limits (i,j)
   INTEGER, PUBLIC, DIMENSION(jpncs)   ::   ncsnr            !: number of point where run-off pours
   INTEGER, PUBLIC, DIMENSION(jpncs,4) ::   ncsir, ncsjr     !: Location of runoff

   REAL(wp), DIMENSION (jpncs+1)       ::   surf             ! closed sea surface

   !! * Substitutions
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
   !! $Id: closea.F90 3442 2012-08-07 11:15:44Z beppe $
   !! Software governed by the CeCILL licence     (NEMOGCM/NEMO_CeCILL.txt)
   !!----------------------------------------------------------------------
CONTAINS

   SUBROUTINE dom_clo
      !!---------------------------------------------------------------------
      !!                  ***  ROUTINE dom_clo  ***
      !!        
      !! ** Purpose :   Closed sea domain initialization
      !!
      !! ** Method  :   if a closed sea is located only in a model grid point
      !!                just the thermodynamic processes are applied.
      !!
      !! ** Action  :   ncsi1(), ncsj1() : south-west closed sea limits (i,j)
      !!                ncsi2(), ncsj2() : north-east Closed sea limits (i,j)
      !!                ncsir(), ncsjr() : Location of runoff
      !!                ncsnr            : number of point where run-off pours
      !!                ncstt            : Type of closed sea
      !!                                   =0 spread over the world ocean
      !!                                   =2 put at location runoff
      !!----------------------------------------------------------------------
      INTEGER ::   jc            ! dummy loop indices
      !!----------------------------------------------------------------------
      
      IF(lwp) WRITE(numout,*)
      IF(lwp) WRITE(numout,*)'dom_clo : closed seas '
      IF(lwp) WRITE(numout,*)'~~~~~~~'

      ! initial values
      ncsnr(:) = 1  ;  ncsi1(:) = 1  ;  ncsi2(:) = 1  ;  ncsir(:,:) = 1
      ncstt(:) = 0  ;  ncsj1(:) = 1  ;  ncsj2(:) = 1  ;  ncsjr(:,:) = 1

      ! set the closed seas (in data domain indices)
      ! -------------------

      IF( cp_cfg == "orca" ) THEN
         !
         SELECT CASE ( jp_cfg )
         !                                           ! =======================
         CASE ( 1 )                                  ! ORCA_R1 configuration
            !                                        ! =======================
            ncsnr(1)   = 1    ; ncstt(1)   = 0           ! Caspian Sea
            ncsi1(1)   = 332  ; ncsj1(1)   = 203
            ncsi2(1)   = 344  ; ncsj2(1)   = 235
            ncsir(1,1) = 1    ; ncsjr(1,1) = 1
            !                                        
            !                                        ! =======================
         CASE ( 2 )                                  !  ORCA_R2 configuration
            !                                        ! =======================
            !                                            ! Caspian Sea
            ncsnr(1)   =   1  ;  ncstt(1)   =   0           ! spread over the globe
            ncsi1(1)   =  11  ;  ncsj1(1)   = 103
            ncsi2(1)   =  17  ;  ncsj2(1)   = 112
            ncsir(1,1) =   1  ;  ncsjr(1,1) =   1 
            !                                            ! Great North American Lakes
            ncsnr(2)   =   1  ;  ncstt(2)   =   2           ! put at St Laurent mouth
            ncsi1(2)   =  97  ;  ncsj1(2)   = 107
            ncsi2(2)   = 103  ;  ncsj2(2)   = 111
            ncsir(2,1) = 110  ;  ncsjr(2,1) = 111
            !                                            ! Black Sea 1 : west part of the Black Sea 
            ncsnr(3)   = 1    ; ncstt(3)   =   2            !            (ie west of the cyclic b.c.)
            ncsi1(3)   = 174  ; ncsj1(3)   = 107            ! put in Med Sea
            ncsi2(3)   = 181  ; ncsj2(3)   = 112
            ncsir(3,1) = 171  ; ncsjr(3,1) = 106 
            !                                            ! Black Sea 2 : est part of the Black Sea 
            ncsnr(4)   =   1  ;  ncstt(4)   =   2           !               (ie est of the cyclic b.c.)
            ncsi1(4)   =   2  ;  ncsj1(4)   = 107           ! put in Med Sea
            ncsi2(4)   =   6  ;  ncsj2(4)   = 112
            ncsir(4,1) = 171  ;  ncsjr(4,1) = 106 
            !                                        ! =======================
         CASE ( 4 )                                  !  ORCA_R4 configuration
            !                                        ! =======================
            !                                            ! Caspian Sea
            ncsnr(1)   =  1  ;  ncstt(1)   =  0  
            ncsi1(1)   =  4  ;  ncsj1(1)   = 53 
            ncsi2(1)   =  4  ;  ncsj2(1)   = 56
            ncsir(1,1) =  1  ;  ncsjr(1,1) =  1
            !                                            ! Great North American Lakes
            ncsnr(2)   =  1  ;  ncstt(2)   =  2 
            ncsi1(2)   = 49  ;  ncsj1(2)   = 55
            ncsi2(2)   = 51  ;  ncsj2(2)   = 56
            ncsir(2,1) = 57  ;  ncsjr(2,1) = 55
            !                                            ! Black Sea
            ncsnr(3)   =  4  ;  ncstt(3)   =  2  
            ncsi1(3)   = 88  ;  ncsj1(3)   = 55 
            ncsi2(3)   = 91  ;  ncsj2(3)   = 56
            ncsir(3,1) = 86  ;  ncsjr(3,1) = 53
            ncsir(3,2) = 87  ;  ncsjr(3,2) = 53 
            ncsir(3,3) = 86  ;  ncsjr(3,3) = 52 
            ncsir(3,4) = 87  ;  ncsjr(3,4) = 52
            !                                            ! Baltic Sea
            ncsnr(4)   =  1  ;  ncstt(4)   =  2
            ncsi1(4)   = 75  ;  ncsj1(4)   = 59
            ncsi2(4)   = 76  ;  ncsj2(4)   = 61
            ncsir(4,1) = 84  ;  ncsjr(4,1) = 59 
            !                                        ! =======================
         CASE ( 025 )                                ! ORCA_R025 configuration
            !                                        ! =======================
            ncsnr(1)   = 1    ; ncstt(1)   = 0               ! Caspian + Aral sea
            ncsi1(1)   = 1330 ; ncsj1(1)   = 645
            ncsi2(1)   = 1400 ; ncsj2(1)   = 795
            ncsir(1,1) = 1    ; ncsjr(1,1) = 1
            !                                        
            ncsnr(2)   = 1    ; ncstt(2)   = 0               ! Azov Sea 
            ncsi1(2)   = 1284 ; ncsj1(2)   = 722
            ncsi2(2)   = 1304 ; ncsj2(2)   = 747
            ncsir(2,1) = 1    ; ncsjr(2,1) = 1
            !
         END SELECT
         !
      ENDIF

      ! convert the position in local domain indices
      ! --------------------------------------------
      DO jc = 1, jpncs
         ncsi1(jc)   = mi0( ncsi1(jc) )
         ncsj1(jc)   = mj0( ncsj1(jc) )

         ncsi2(jc)   = mi1( ncsi2(jc) )   
         ncsj2(jc)   = mj1( ncsj2(jc) )  
      END DO
      !
   END SUBROUTINE dom_clo


   SUBROUTINE sbc_clo( kt )
      !!---------------------------------------------------------------------
      !!                  ***  ROUTINE sbc_clo  ***
      !!                    
      !! ** Purpose :   Special handling of closed seas
      !!
      !! ** Method  :   Water flux is forced to zero over closed sea
      !!      Excess is shared between remaining ocean, or
      !!      put as run-off in open ocean.
      !!
      !! ** Action  :   emp, emps   updated surface freshwater fluxes at kt
      !!----------------------------------------------------------------------
      INTEGER, INTENT(in) ::   kt   ! ocean model time step
      !
      INTEGER             ::   ji, jj, jc, jn   ! dummy loop indices
      REAL(wp), PARAMETER ::   rsmall = 1.e-20_wp    ! Closed sea correction epsilon
      REAL(wp)            ::   zze2, ztmp, zcorr     ! 
      COMPLEX(wp)         ::   ctmp 
      REAL(wp), DIMENSION(jpncs) ::   zfwf   ! 1D workspace
      !!----------------------------------------------------------------------
      !
      IF( nn_timing == 1 )  CALL timing_start('sbc_clo')
      !                                                   !------------------!
      IF( kt == nit000 ) THEN                             !  Initialisation  !
         !                                                !------------------!
         IF(lwp) WRITE(numout,*)
         IF(lwp) WRITE(numout,*)'sbc_clo : closed seas '
         IF(lwp) WRITE(numout,*)'~~~~~~~'

         surf(:) = 0.e0_wp
         !
         surf(jpncs+1) = glob_sum( e1e2t(:,:) )   ! surface of the global ocean
         !
         !                                        ! surface of closed seas 
         IF( lk_mpp_rep ) THEN                         ! MPP reproductible calculation
            DO jc = 1, jpncs
               ctmp = CMPLX( 0.e0, 0.e0, wp )
               DO jj = ncsj1(jc), ncsj2(jc)
                  DO ji = ncsi1(jc), ncsi2(jc)
                     ztmp = e1e2t(ji,jj) * tmask_i(ji,jj)
                     CALL DDPDD( CMPLX( ztmp, 0.e0, wp ), ctmp )
                  END DO 
               END DO 
               IF( lk_mpp )   CALL mpp_sum( ctmp )
               surf(jc) = REAL(ctmp,wp)
            END DO
         ELSE                                          ! Standard calculation           
            DO jc = 1, jpncs
               DO jj = ncsj1(jc), ncsj2(jc)
                  DO ji = ncsi1(jc), ncsi2(jc)
                     surf(jc) = surf(jc) + e1e2t(ji,jj) * tmask_i(ji,jj)      ! surface of closed seas
                  END DO 
               END DO 
            END DO 
            IF( lk_mpp )   CALL mpp_sum ( surf, jpncs )       ! mpp: sum over all the global domain
         ENDIF

         IF(lwp) WRITE(numout,*)'     Closed sea surfaces'
         DO jc = 1, jpncs
            IF(lwp)WRITE(numout,FMT='(1I3,4I4,5X,F16.2)') jc, ncsi1(jc), ncsi2(jc), ncsj1(jc), ncsj2(jc), surf(jc)
         END DO

         ! jpncs+1 : surface of sea, closed seas excluded
         DO jc = 1, jpncs
            surf(jpncs+1) = surf(jpncs+1) - surf(jc)
         END DO           
         !
      ENDIF
      !                                                   !--------------------!
      !                                                   !  update emp, emps  !
      zfwf = 0.e0_wp                                      !--------------------!
      IF( lk_mpp_rep ) THEN                         ! MPP reproductible calculation
         DO jc = 1, jpncs
            ctmp = CMPLX( 0.e0, 0.e0, wp )
            DO jj = ncsj1(jc), ncsj2(jc)
               DO ji = ncsi1(jc), ncsi2(jc)
                  ztmp = e1e2t(ji,jj) * ( emp(ji,jj)-rnf(ji,jj) ) * tmask_i(ji,jj)
                  CALL DDPDD( CMPLX( ztmp, 0.e0, wp ), ctmp )
               END DO  
            END DO 
            IF( lk_mpp )   CALL mpp_sum( ctmp )
            zfwf(jc) = REAL(ctmp,wp)
         END DO
      ELSE                                          ! Standard calculation           
         DO jc = 1, jpncs
            DO jj = ncsj1(jc), ncsj2(jc)
               DO ji = ncsi1(jc), ncsi2(jc)
                  zfwf(jc) = zfwf(jc) + e1e2t(ji,jj) * ( emp(ji,jj)-rnf(ji,jj) ) * tmask_i(ji,jj) 
               END DO  
            END DO 
         END DO
         IF( lk_mpp )   CALL mpp_sum ( zfwf(:) , jpncs )       ! mpp: sum over all the global domain
      ENDIF

      IF( cp_cfg == "orca" .AND. jp_cfg == 2 ) THEN      ! Black Sea case for ORCA_R2 configuration
         zze2    = ( zfwf(3) + zfwf(4) ) * 0.5_wp
         zfwf(3) = zze2
         zfwf(4) = zze2
      ENDIF

      zcorr = 0._wp

      DO jc = 1, jpncs
         !
         ! The following if avoids the redistribution of the round off
         IF ( ABS(zfwf(jc) / surf(jpncs+1) ) > rsmall) THEN
            !
            IF( ncstt(jc) == 0 ) THEN           ! water/evap excess is shared by all open ocean
               emp (:,:) = emp (:,:) + zfwf(jc) / surf(jpncs+1)
               emps(:,:) = emps(:,:) + zfwf(jc) / surf(jpncs+1)
               ! accumulate closed seas correction
               zcorr     = zcorr     + zfwf(jc) / surf(jpncs+1)
               !
            ELSEIF( ncstt(jc) == 1 ) THEN       ! Excess water in open sea, at outflow location, excess evap shared
               IF ( zfwf(jc) <= 0.e0_wp ) THEN 
                   DO jn = 1, ncsnr(jc)
                     ji = mi0(ncsir(jc,jn))
                     jj = mj0(ncsjr(jc,jn)) ! Location of outflow in open ocean
                     IF (      ji > 1 .AND. ji < jpi   &
                         .AND. jj > 1 .AND. jj < jpj ) THEN 
                         emp (ji,jj) = emp (ji,jj) + zfwf(jc) / ( REAL(ncsnr(jc)) * e1e2t(ji,jj) )
                         emps(ji,jj) = emps(ji,jj) + zfwf(jc) / ( REAL(ncsnr(jc)) * e1e2t(ji,jj) )
                     ENDIF 
                   END DO 
               ELSE 
                   emp (:,:) = emp (:,:) + zfwf(jc) / surf(jpncs+1)
                   emps(:,:) = emps(:,:) + zfwf(jc) / surf(jpncs+1)
                   ! accumulate closed seas correction
                   zcorr     = zcorr     + zfwf(jc) / surf(jpncs+1)
               ENDIF
            ELSEIF( ncstt(jc) == 2 ) THEN       ! Excess e-p-r (either sign) goes to open ocean, at outflow location
               DO jn = 1, ncsnr(jc)
                  ji = mi0(ncsir(jc,jn))
                  jj = mj0(ncsjr(jc,jn)) ! Location of outflow in open ocean
                  IF(      ji > 1 .AND. ji < jpi    &
                     .AND. jj > 1 .AND. jj < jpj ) THEN 
                     emp (ji,jj) = emp (ji,jj) + zfwf(jc) / ( REAL(ncsnr(jc)) *  e1e2t(ji,jj) )
                     emps(ji,jj) = emps(ji,jj) + zfwf(jc) / ( REAL(ncsnr(jc)) *  e1e2t(ji,jj) )
                  ENDIF 
               END DO 
            ENDIF 
            !
            DO jj = ncsj1(jc), ncsj2(jc)
               DO ji = ncsi1(jc), ncsi2(jc)
                  emp (ji,jj) = emp (ji,jj) - zfwf(jc) / surf(jc)
                  emps(ji,jj) = emps(ji,jj) - zfwf(jc) / surf(jc)
               END DO  
            END DO 
            !
         END IF
      END DO 

      IF ( ABS(zcorr) > rsmall ) THEN      ! remove the global correction from the closed seas
         DO jc = 1, jpncs                  ! only if it is large enough
            DO jj = ncsj1(jc), ncsj2(jc)
               DO ji = ncsi1(jc), ncsi2(jc)
                  emp (ji,jj) = emp (ji,jj) - zcorr
                  emps(ji,jj) = emps(ji,jj) - zcorr
               END DO  
             END DO 
          END DO
      ENDIF
      !
      emp (:,:) = emp (:,:) * tmask(:,:,1)
      emps(:,:) = emps(:,:) * tmask(:,:,1)
      !
      CALL lbc_lnk( emp , 'T', 1._wp )
      CALL lbc_lnk( emps, 'T', 1._wp )
      !
      IF( nn_timing == 1 )  CALL timing_stop('sbc_clo')
      !
   END SUBROUTINE sbc_clo


   SUBROUTINE clo_rnf( p_rnfmsk )
      !!---------------------------------------------------------------------
      !!                  ***  ROUTINE sbc_rnf  ***
      !!                    
      !! ** Purpose :   allow the treatment of closed sea outflow grid-points
      !!                to be the same as river mouth grid-points
      !!
      !! ** Method  :   set to 1 the runoff mask (mskrnf, see sbcrnf module)
      !!                at the closed sea outflow grid-point.
      !!
      !! ** Action  :   update (p_)mskrnf (set 1 at closed sea outflow)
      !!----------------------------------------------------------------------
      REAL(wp), DIMENSION(jpi,jpj), INTENT(inout) ::   p_rnfmsk   ! river runoff mask (rnfmsk array)
      !
      INTEGER  ::   jc, jn      ! dummy loop indices
      INTEGER  ::   ii, ij      ! temporary integer
      !!----------------------------------------------------------------------
      !
      DO jc = 1, jpncs
         IF( ncstt(jc) >= 1 ) THEN            ! runoff mask set to 1 at closed sea outflows
             DO jn = 1, 4
               ii = mi0( ncsir(jc,jn) )
               ij = mj0( ncsjr(jc,jn) )
               p_rnfmsk(ii,ij) = MAX( p_rnfmsk(ii,ij), 1.0_wp )
            END DO 
         ENDIF 
      END DO 
      !
   END SUBROUTINE clo_rnf

   
   SUBROUTINE clo_ups( p_upsmsk )
      !!---------------------------------------------------------------------
      !!                  ***  ROUTINE sbc_rnf  ***
      !!                    
      !! ** Purpose :   allow the treatment of closed sea outflow grid-points
      !!                to be the same as river mouth grid-points
      !!
      !! ** Method  :   set to 0.5 the upstream mask (upsmsk, see traadv_cen2 
      !!                module) over the closed seas.
      !!
      !! ** Action  :   update (p_)upsmsk (set 0.5 over closed seas)
      !!----------------------------------------------------------------------
      REAL(wp), DIMENSION(jpi,jpj), INTENT(inout) ::   p_upsmsk   ! upstream mask (upsmsk array)
      !
      INTEGER  ::   jc, ji, jj      ! dummy loop indices
      !!----------------------------------------------------------------------
      !
      DO jc = 1, jpncs
         DO jj = ncsj1(jc), ncsj2(jc)
            DO ji = ncsi1(jc), ncsi2(jc)
               p_upsmsk(ji,jj) = 0.5_wp         ! mixed upstream/centered scheme over closed seas
            END DO 
         END DO 
       END DO 
       !
   END SUBROUTINE clo_ups
   
      
   SUBROUTINE clo_bat( pbat, kbat )
      !!---------------------------------------------------------------------
      !!                  ***  ROUTINE clo_bat  ***
      !!                    
      !! ** Purpose :   suppress closed sea from the domain
      !!
      !! ** Method  :   set to 0 the meter and level bathymetry (given in 
      !!                arguments) over the closed seas.
      !!
      !! ** Action  :   set pbat=0 and kbat=0 over closed seas
      !!----------------------------------------------------------------------
      REAL(wp), DIMENSION(jpi,jpj), INTENT(inout) ::   pbat   ! bathymetry in meters (bathy array)
      INTEGER , DIMENSION(jpi,jpj), INTENT(inout) ::   kbat   ! bathymetry in levels (mbathy array)
      !
      INTEGER  ::   jc, ji, jj      ! dummy loop indices
      !!----------------------------------------------------------------------
      !
      DO jc = 1, jpncs
         DO jj = ncsj1(jc), ncsj2(jc)
            DO ji = ncsi1(jc), ncsi2(jc)
               pbat(ji,jj) = 0._wp   
               kbat(ji,jj) = 0   
            END DO 
         END DO 
       END DO 
       !
   END SUBROUTINE clo_bat

   !!======================================================================
END MODULE closea
