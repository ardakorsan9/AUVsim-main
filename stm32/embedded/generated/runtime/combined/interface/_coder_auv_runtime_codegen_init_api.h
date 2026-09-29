//
// Academic License - for use in teaching, academic research, and meeting
// course requirements at degree granting institutions only.  Not for
// government, commercial, or other organizational use.
// File: _coder_auv_runtime_codegen_init_api.h
//
// MATLAB Coder version            : 25.2
// C/C++ source code generated on  : 28-Aug-2026 17:25:48
//

#ifndef _CODER_AUV_RUNTIME_CODEGEN_INIT_API_H
#define _CODER_AUV_RUNTIME_CODEGEN_INIT_API_H

// Include Files
#include "emlrt.h"
#include "mex.h"
#include "tmwtypes.h"
#include <algorithm>
#include <cstring>

// Type Definitions
struct struct2_T {
  real_T MAX_PATH_POINTS;
  real_T lookahead_distance;
  real_T desired_speed;
  real_T pitch_ref_max;
  real_T pitch_ref_rate_max;
  real_T dt_guidance;
  real_T dt_controller;
  real_T K_zdot;
  real_T K_gamma;
  boolean_T enable_alpha_hat;
  real_T k_beta;
  real_T closed_eps;
  real_T near_end_margin;
  real_T mono_back_max;
  real_T s_back_tol;
  real_T yaw_slew_max_rad_s;
  real_T r_ff_max_rad_s;
  real_T pitch_corr_max;
  real_T z_e_i_max;
  real_T alpha_hat_max;
};

struct struct3_T {
  boolean_T present[7];
  real_T period[7];
  real_T stale_limit[7];
};

struct struct4_T {
  real_T G_nom;
  real_T thr_B2;
  real_T eps_dr_rad;
  real_T u_floor;
  real_T t_warmup_s;
  real_T Np;
  real_T persist_s;
  real_T dt;
};

struct struct6_T {
  real_T g_ned;
  real_T sigma_p;
  real_T sigma_a;
  real_T sigma_g;
  real_T sigma_bg;
  real_T sigma_ba;
  real_T sigma_c;
  real_T R_depth;
  real_T R_heading;
  real_T R_ins[3];
  real_T R_dvl[3];
  real_T R_usbl[3];
  real_T lat_depth;
  real_T lat_heading;
  real_T lat_ins;
  real_T lat_dvl;
  real_T lat_usbl;
  real_T P0_p[3];
  real_T P0_p_abs;
  real_T P0_v[3];
  real_T P0_th[3];
  real_T P0_bg[3];
  real_T P0_ba[3];
  real_T P0_c[3];
  real_T q_min_frac;
  real_T q_floor;
  real_T nis_scale;
  real_T dt_prop_max;
  real_T dt_prop_sub;
  real_T n_sub_max;
  real_T tol_time;
  real_T tol_pair;
  boolean_T config_valid;
};

struct struct7_T {
  real_T T_degrade;
  real_T T_lost;
  real_T T_reacq;
  real_T T_clear;
  real_T T_settle;
  real_T tol_time;
  real_T k_fresh;
  real_T tau_floor;
  boolean_T present[7];
  real_T period[7];
  real_T stale_limit[7];
  real_T tau_fresh[7];
  boolean_T config_valid;
};

struct struct8_T {
  real_T G_nom;
  real_T thr_B2;
  real_T eps_dr_rad;
  real_T u_floor;
  real_T t_warmup_s;
  real_T Np;
  real_T persist_s;
  real_T dt;
  boolean_T config_valid;
};

struct struct10_T {
  real_T prev_delta_r;
  real_T prev_delta_e;
  real_T int_angle;
  real_T int_rate;
  real_T rate_filt;
  real_T prev_e_rate;
  real_T initialized;
};

struct struct11_T {
  boolean_T initialized;
  real_T s_prog;
  real_T yaw_cont;
  real_T pitch_f;
  real_T z_e_f;
  real_T z_e_i;
  real_T zd_e_f;
  real_T eg_f;
  real_T alpha_hat;
  real_T kappa_f;
  real_T chi_f;
  real_T yaw_out;
  real_T pitch_out;
  boolean_T have_yaw_cont;
  boolean_T have_pitch_f;
  boolean_T have_chi_f;
  boolean_T have_yaw_out;
};

struct struct13_T {
  uint8_T code;
  real_T deg_timer;
  real_T loss_timer;
  real_T posok_timer;
  real_T allok_timer;
  real_T last_accept_t[7];
  boolean_T have_accept[7];
  real_T init_time;
  real_T last_t;
  boolean_T have_init;
  boolean_T have_t;
  uint32_T trans_count;
  uint8_T trans_from;
  uint8_T trans_to;
};

struct struct14_T {
  boolean_T initialized;
  real_T persist_count;
  boolean_T anomaly_latched;
  real_T alarm_time_s;
  boolean_T alarm_time_valid;
  uint32_T last_seq;
  boolean_T have_seq;
};

struct struct16_T {
  uint8_T op;
  boolean_T sample_valid;
  real_T t;
  real_T init_gyro[3];
  real_T init_accel[3];
  real_T init_depth;
  real_T init_heading;
  real_T init_ins_vel[3];
  real_T init_timestamp[5];
  real_T init_seq[5];
  boolean_T abs_position_present;
  real_T gyro[3];
  real_T accel[3];
  real_T gyro_timestamp;
  real_T accel_timestamp;
  uint32_T gyro_seq;
  uint32_T accel_seq;
  uint8_T channel;
  uint8_T dim;
  boolean_T present;
  boolean_T packet_valid;
  uint8_T status;
  real_T value[3];
  real_T timestamp;
  real_T quality;
  real_T stale_age;
  real_T bound_lo[3];
  real_T bound_hi[3];
  real_T q_nom;
  real_T stale_limit_s;
  uint32_T seq;
};

struct struct15_T {
  real_T t;
  uint32_T tick_seq;
  boolean_T sample_valid;
  boolean_T arm_request;
  boolean_T disarm_request;
  boolean_T kill_asserted;
  struct16_T nav;
  real_T path_pad[96];
  real_T n_path;
  real_T body_rates[3];
  boolean_T accepted[7];
};

struct struct17_T {
  real_T delta_r;
  real_T delta_e;
  real_T thrust;
  boolean_T command_valid;
  uint8_T arm_state;
  boolean_T ready;
  uint32_T healthy_streak;
  uint32_T health_bits;
  uint32_T fault_bits_latched;
  uint32_T tick_count;
  real_T yaw;
  real_T pitch;
  real_T u;
  real_T r_ff;
  real_T pitch_dot;
  real_T progress_index;
  boolean_T guidance_due;
  boolean_T guidance_ready;
  real_T nav_p[3];
  real_T nav_v[3];
  real_T nav_euler[3];
  real_T nav_vel_body_water[3];
  boolean_T nav_valid;
  boolean_T nav_initialized;
  uint32_T nav_health_bits;
  uint8_T availability_state;
  uint32_T availability_health_bits;
  real_T fdir_residual;
  boolean_T fdir_anomaly_latched;
  uint32_T fdir_health_bits;
  real_T ctrl_delta_r;
  real_T ctrl_delta_e;
  real_T ctrl_thrust;
  boolean_T physical_io_written;
  boolean_T actuator_isolated;
  boolean_T abort_requested;
};

struct struct1_T {
  real_T Kp_psi;
  real_T Kd_psi;
  real_T Kp_x;
  real_T Kp_roll;
  real_T Kp_angle;
  real_T Ki_angle;
  real_T Kp_rate;
  real_T Ki_rate;
  real_T Kaw_pitch;
  real_T Kd_rate;
  real_T Kd_damp;
  real_T delta_r_max;
  real_T delta_e_max;
  real_T thrust_max;
  real_T thrust_min;
  real_T thrust_trim;
  real_T trim_speed_table[4];
  real_T trim_elevator_table[4];
  real_T elevator_sign;
  real_T dt_controller;
  real_T tau_rate;
  real_T Muw;
  real_T Muuds;
  real_T lambda_muw_ff;
  real_T muw_ff_u_min;
  real_T muw_ff_u_lo;
  real_T muw_ff_u_hi;
  real_T muw_ff_clamp_deg;
  real_T delta_e_trim;
  real_T k_gamma_climb;
  real_T de_climb_lim;
  real_T slew_max_rad_s;
};

struct struct0_T {
  struct1_T controller;
  struct2_T guidance;
  struct3_T availability;
  struct4_T fdir;
  real_T safe_thrust;
};

struct struct5_T {
  struct1_T controller;
  struct2_T guidance;
  struct6_T navigation;
  struct7_T availability;
  struct8_T fdir;
  real_T safe_thrust;
  uint32_T guidance_divider;
  uint32_T arm_min_healthy_ticks;
  boolean_T config_valid;
};

struct struct12_T {
  boolean_T initialized;
  real_T p[3];
  real_T v[3];
  real_T q[4];
  real_T bg[3];
  real_T ba[3];
  real_T c[3];
  real_T P[324];
  uint32_T last_seq[7];
  boolean_T have_seq[7];
  real_T last_ts[7];
  boolean_T have_ts[7];
  real_T last_accept_t[7];
  boolean_T have_accept_t[7];
  uint32_T est_seq;
};

struct struct9_T {
  struct10_T controller;
  struct11_T guidance;
  struct12_T navigation;
  struct13_T availability;
  struct14_T fdir;
  uint32_T tick_count;
  boolean_T have_tick;
  uint32_T last_tick_seq;
  real_T last_t;
  real_T progress_index;
  real_T yaw;
  real_T pitch;
  real_T u;
  real_T r_ff;
  real_T pitch_dot;
  boolean_T guidance_ready;
  uint8_T arm_state;
  uint32_T healthy_streak;
  uint32_T fault_bits_latched;
};

// Variable Declarations
extern emlrtCTX emlrtRootTLSGlobal;
extern emlrtContext emlrtContextGlobal;

// Function Declarations
void auv_runtime_codegen_init(struct0_T *cfg, struct5_T *params);

void auv_runtime_codegen_init_api(const mxArray *prhs, const mxArray **plhs);

void auv_runtime_codegen_init_atexit();

void auv_runtime_codegen_init_initialize();

void auv_runtime_codegen_init_terminate();

void auv_runtime_codegen_init_xil_shutdown();

void auv_runtime_codegen_init_xil_terminate();

void auv_runtime_codegen_reset(struct5_T *params, struct9_T *state);

void auv_runtime_codegen_reset_api(const mxArray *prhs, const mxArray **plhs);

void auv_runtime_codegen_step(struct5_T *params, struct9_T *state,
                              struct15_T *in, struct17_T *out);

void auv_runtime_codegen_step_api(const mxArray *const prhs[3], int32_T nlhs,
                                  const mxArray *plhs[2]);

#endif
//
// File trailer for _coder_auv_runtime_codegen_init_api.h
//
// [EOF]
//
