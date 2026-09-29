//
// Academic License - for use in teaching, academic research, and meeting
// course requirements at degree granting institutions only.  Not for
// government, commercial, or other organizational use.
// File: auv_runtime_codegen_init_types.h
//
// MATLAB Coder version            : 25.2
// C/C++ source code generated on  : 28-Aug-2026 17:25:48
//

#ifndef AUV_RUNTIME_CODEGEN_INIT_TYPES_H
#define AUV_RUNTIME_CODEGEN_INIT_TYPES_H

// Include Files
#include "rtwtypes.h"

// Type Definitions
struct struct2_T {
  double MAX_PATH_POINTS;
  double lookahead_distance;
  double desired_speed;
  double pitch_ref_max;
  double pitch_ref_rate_max;
  double dt_guidance;
  double dt_controller;
  double K_zdot;
  double K_gamma;
  bool enable_alpha_hat;
  double k_beta;
  double closed_eps;
  double near_end_margin;
  double mono_back_max;
  double s_back_tol;
  double yaw_slew_max_rad_s;
  double r_ff_max_rad_s;
  double pitch_corr_max;
  double z_e_i_max;
  double alpha_hat_max;
};

struct struct3_T {
  bool present[7];
  double period[7];
  double stale_limit[7];
};

struct struct4_T {
  double G_nom;
  double thr_B2;
  double eps_dr_rad;
  double u_floor;
  double t_warmup_s;
  double Np;
  double persist_s;
  double dt;
};

struct struct6_T {
  double g_ned;
  double sigma_p;
  double sigma_a;
  double sigma_g;
  double sigma_bg;
  double sigma_ba;
  double sigma_c;
  double R_depth;
  double R_heading;
  double R_ins[3];
  double R_dvl[3];
  double R_usbl[3];
  double lat_depth;
  double lat_heading;
  double lat_ins;
  double lat_dvl;
  double lat_usbl;
  double P0_p[3];
  double P0_p_abs;
  double P0_v[3];
  double P0_th[3];
  double P0_bg[3];
  double P0_ba[3];
  double P0_c[3];
  double q_min_frac;
  double q_floor;
  double nis_scale;
  double dt_prop_max;
  double dt_prop_sub;
  double n_sub_max;
  double tol_time;
  double tol_pair;
  bool config_valid;
};

struct struct7_T {
  double T_degrade;
  double T_lost;
  double T_reacq;
  double T_clear;
  double T_settle;
  double tol_time;
  double k_fresh;
  double tau_floor;
  bool present[7];
  double period[7];
  double stale_limit[7];
  double tau_fresh[7];
  bool config_valid;
};

struct struct8_T {
  double G_nom;
  double thr_B2;
  double eps_dr_rad;
  double u_floor;
  double t_warmup_s;
  double Np;
  double persist_s;
  double dt;
  bool config_valid;
};

struct struct10_T {
  double prev_delta_r;
  double prev_delta_e;
  double int_angle;
  double int_rate;
  double rate_filt;
  double prev_e_rate;
  double initialized;
};

struct struct11_T {
  bool initialized;
  double s_prog;
  double yaw_cont;
  double pitch_f;
  double z_e_f;
  double z_e_i;
  double zd_e_f;
  double eg_f;
  double alpha_hat;
  double kappa_f;
  double chi_f;
  double yaw_out;
  double pitch_out;
  bool have_yaw_cont;
  bool have_pitch_f;
  bool have_chi_f;
  bool have_yaw_out;
};

struct struct13_T {
  unsigned char code;
  double deg_timer;
  double loss_timer;
  double posok_timer;
  double allok_timer;
  double last_accept_t[7];
  bool have_accept[7];
  double init_time;
  double last_t;
  bool have_init;
  bool have_t;
  unsigned int trans_count;
  unsigned char trans_from;
  unsigned char trans_to;
};

struct struct14_T {
  bool initialized;
  double persist_count;
  bool anomaly_latched;
  double alarm_time_s;
  bool alarm_time_valid;
  unsigned int last_seq;
  bool have_seq;
};

struct struct16_T {
  unsigned char op;
  bool sample_valid;
  double t;
  double init_gyro[3];
  double init_accel[3];
  double init_depth;
  double init_heading;
  double init_ins_vel[3];
  double init_timestamp[5];
  double init_seq[5];
  bool abs_position_present;
  double gyro[3];
  double accel[3];
  double gyro_timestamp;
  double accel_timestamp;
  unsigned int gyro_seq;
  unsigned int accel_seq;
  unsigned char channel;
  unsigned char dim;
  bool present;
  bool packet_valid;
  unsigned char status;
  double value[3];
  double timestamp;
  double quality;
  double stale_age;
  double bound_lo[3];
  double bound_hi[3];
  double q_nom;
  double stale_limit_s;
  unsigned int seq;
};

struct struct15_T {
  double t;
  unsigned int tick_seq;
  bool sample_valid;
  bool arm_request;
  bool disarm_request;
  bool kill_asserted;
  struct16_T nav;
  double path_pad[96];
  double n_path;
  double body_rates[3];
  bool accepted[7];
};

struct struct17_T {
  double delta_r;
  double delta_e;
  double thrust;
  bool command_valid;
  unsigned char arm_state;
  bool ready;
  unsigned int healthy_streak;
  unsigned int health_bits;
  unsigned int fault_bits_latched;
  unsigned int tick_count;
  double yaw;
  double pitch;
  double u;
  double r_ff;
  double pitch_dot;
  double progress_index;
  bool guidance_due;
  bool guidance_ready;
  double nav_p[3];
  double nav_v[3];
  double nav_euler[3];
  double nav_vel_body_water[3];
  bool nav_valid;
  bool nav_initialized;
  unsigned int nav_health_bits;
  unsigned char availability_state;
  unsigned int availability_health_bits;
  double fdir_residual;
  bool fdir_anomaly_latched;
  unsigned int fdir_health_bits;
  double ctrl_delta_r;
  double ctrl_delta_e;
  double ctrl_thrust;
  bool physical_io_written;
  bool actuator_isolated;
  bool abort_requested;
};

struct struct1_T {
  double Kp_psi;
  double Kd_psi;
  double Kp_x;
  double Kp_roll;
  double Kp_angle;
  double Ki_angle;
  double Kp_rate;
  double Ki_rate;
  double Kaw_pitch;
  double Kd_rate;
  double Kd_damp;
  double delta_r_max;
  double delta_e_max;
  double thrust_max;
  double thrust_min;
  double thrust_trim;
  double trim_speed_table[4];
  double trim_elevator_table[4];
  double elevator_sign;
  double dt_controller;
  double tau_rate;
  double Muw;
  double Muuds;
  double lambda_muw_ff;
  double muw_ff_u_min;
  double muw_ff_u_lo;
  double muw_ff_u_hi;
  double muw_ff_clamp_deg;
  double delta_e_trim;
  double k_gamma_climb;
  double de_climb_lim;
  double slew_max_rad_s;
};

struct struct0_T {
  struct1_T controller;
  struct2_T guidance;
  struct3_T availability;
  struct4_T fdir;
  double safe_thrust;
};

struct struct5_T {
  struct1_T controller;
  struct2_T guidance;
  struct6_T navigation;
  struct7_T availability;
  struct8_T fdir;
  double safe_thrust;
  unsigned int guidance_divider;
  unsigned int arm_min_healthy_ticks;
  bool config_valid;
};

struct struct12_T {
  bool initialized;
  double p[3];
  double v[3];
  double q[4];
  double bg[3];
  double ba[3];
  double c[3];
  double P[324];
  unsigned int last_seq[7];
  bool have_seq[7];
  double last_ts[7];
  bool have_ts[7];
  double last_accept_t[7];
  bool have_accept_t[7];
  unsigned int est_seq;
};

struct struct9_T {
  struct10_T controller;
  struct11_T guidance;
  struct12_T navigation;
  struct13_T availability;
  struct14_T fdir;
  unsigned int tick_count;
  bool have_tick;
  unsigned int last_tick_seq;
  double last_t;
  double progress_index;
  double yaw;
  double pitch;
  double u;
  double r_ff;
  double pitch_dot;
  bool guidance_ready;
  unsigned char arm_state;
  unsigned int healthy_streak;
  unsigned int fault_bits_latched;
};

#endif
//
// File trailer for auv_runtime_codegen_init_types.h
//
// [EOF]
//
