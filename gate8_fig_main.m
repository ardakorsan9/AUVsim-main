function gate8_fig_main(A, R0, png_path)
% Main evidence figure for the yaw term dimensional consistency audit.
% All panels are drawn from the stored log and the audit algebra only.

    cols = A.derived_log_cols;
    Dl = A.derived_log;
    gi = @(nm) Dl(:, find(strcmp(cols, nm), 1));

    t      = gi('t');
    e_psi  = gi('e_psi_deg');
    P      = gi('term_P_deg');
    RATE   = gi('term_RATE_ERR_deg');
    DMP    = gi('dr_damp_deg');
    RAW    = gi('dr_raw_deg');
    PMAG   = gi('dr_postmag_recon_deg');
    PLANT  = gi('dr_plant_deg');
    beta   = gi('beta_deg');
    kap    = gi('kappa_f_invm');
    LIM    = A.LIM;

    f = figure('Visible','off','Color','w','Units','inches','Position',[0.5 0.5 13.5 10.5]);
    set(f,'PaperPositionMode','auto');

    % ---- 1: contributions against the envelope ----
    subplot(4,2,1); hold on; grid on;
    plot(t, RAW, 'Color',[0.15 0.15 0.15], 'LineWidth',1.4);
    plot(t, P, 'Color',[0.85 0.20 0.15], 'LineWidth',1.0);
    plot(t, RATE, 'Color',[0.10 0.40 0.85], 'LineWidth',1.0);
    plot(t, DMP, 'Color',[0.05 0.60 0.30], 'LineWidth',1.0);
    plot(t([1 end]), [LIM LIM], 'k--', 'LineWidth',1.2);
    plot(t([1 end]), [-LIM -LIM], 'k--', 'LineWidth',1.2);
    xlabel('t [s]'); ylabel('rudder [deg]');
    title(sprintf('1. Existing contributions vs the %g deg envelope (raw peak %.1f deg = %.1fx)', ...
        LIM, max(abs(RAW)), max(abs(RAW))/LIM));
    legend({'dr\_raw','K_{p\psi}e_\psi','-K_{d\psi}(r-r_{ff})','g_{ac}(-K_{p\phi}p)','\pm envelope'}, ...
        'Location','northeast','FontSize',7);

    % ---- 2: coefficient recovery from stored logs ----
    subplot(4,2,2); hold on; grid on;
    re = max([A.recov.rel_err], 1e-18);
    bar(1:4, re, 0.55, 'FaceColor',[0.20 0.45 0.75]);
    set(gca,'YScale','log','XTick',1:4, ...
        'XTickLabel',{'K_{p\psi}','-K_{d\psi}','+K_{d\psi}','-K_{p\phi}'});
    plot([0.5 4.5], [A.recov_tol A.recov_tol], 'r--','LineWidth',1.3);
    ylim([1e-18 1e-6]);
    ylabel('|observed/code - 1|');
    title('2. Coefficient recovery: contribution / source signal (dashed = 1e-9 tol)');
    for k = 1:4
        text(k, 3e-17, sprintf('%.9g', A.recov(k).median), 'HorizontalAlignment','center', ...
            'FontSize',7, 'Rotation',0);
    end

    % ---- 3: structural, conversion and ordering residuals ----
    subplot(4,2,3); hold on; grid on;
    mv = max([A.res.maxabs], 1e-18);
    bar(1:numel(mv), mv, 0.6, 'FaceColor',[0.35 0.35 0.40]);
    plot([0.5 numel(mv)+0.5], [A.res_tol A.res_tol], 'r--','LineWidth',1.3);
    set(gca,'YScale','log','XTick',1:numel(mv), 'XTickLabel', ...
        {'yaw=P+D+FF','e_r=r-r_{ff}','r_{ff}=U_h\kappa','damp=g_{ac}d_p','g_{ac} 3deg/8degs', ...
         'raw=yaw+damp','mag clamp','rate limit','plant=return'}, 'FontSize',7);
    try; set(gca,'XTickLabelRotation',28); catch; end
    ylim([1e-18 1e-6]); ylabel('max |residual|');
    title(sprintf('3. Structural / unit / limiter-order identities (worst %.2g)', max([A.res.maxabs])));

    % ---- 4: envelope excess ledger ----
    subplot(4,2,4); hold on; grid on;
    ex = [A.ledger.excess_absmax];
    exm = [A.ledger.excess_medabs];
    bar(1:numel(ex), [ex(:) exm(:)], 0.8);
    plot([0.5 numel(ex)+0.5], [1 1], 'k--','LineWidth',1.4);
    set(gca,'YScale','log','XTick',1:numel(ex),'XTickLabel',{A.ledger.term},'FontSize',8);
    ylabel('multiple of envelope'); ylim([1e-3 1e2]);
    legend({'peak','median','envelope'},'Location','northwest','FontSize',7);
    title('4. Envelope excess ledger: how far each term overruns 25 deg');

    % ---- 5: limiter chain, zoomed to the envelope ----
    subplot(4,2,5); hold on; grid on;
    plot(t, max(min(RAW, 60), -60), 'Color',[0.75 0.75 0.78], 'LineWidth',0.9);
    plot(t, PMAG, 'Color',[0.85 0.35 0.10], 'LineWidth',1.1);
    plot(t, PLANT, 'Color',[0.05 0.25 0.65], 'LineWidth',1.1);
    plot(t([1 end]), [LIM LIM], 'k--'); plot(t([1 end]), [-LIM -LIM], 'k--');
    ylim([-32 32]); xlabel('t [s]'); ylabel('rudder [deg]');
    title(sprintf('5. Limiter chain: magnitude then rate (mag dwell %.4f, rate dwell %.4f, rail dwell %.4f)', ...
        A.coupled.magsat_dwell, A.coupled.ratesat_dwell, A.coupled.rail_dwell));
    legend({'raw (clipped view)','after magnitude','plant input'},'Location','southeast','FontSize',7);

    % ---- 6: leave-one-term-out on the limited command ----
    subplot(4,2,6); hold on; grid on;
    ls = A.loto_split; lg = A.loto_group;
    nm = [{ls.term}, {'|'}, {lg.term}];
    fr = [[ls.frac_changed_postmag], NaN, [lg.frac_changed_postmag]];
    rm = [[ls.rms_change_postmag_deg], NaN, [lg.rms_change_postmag_deg]];
    bar(1:numel(fr), fr(:), 0.6, 'FaceColor',[0.20 0.55 0.35]);
    set(gca,'XTick',1:numel(fr),'XTickLabel',nm,'FontSize',8);
    ylabel('fraction of horizon where removal changes the limited command');
    ylim([0 1]);
    for k = 1:numel(fr)
        if isfinite(rm(k))
            text(k, min(fr(k)+0.06, 0.96), sprintf('%.3g deg rms', rm(k)), ...
                'HorizontalAlignment','center','FontSize',6.5);
        end
    end
    title('6. LOTO on the stored raw command: split (left) vs physically grouped (right)');

    % ---- 7: standing-error geometry ----
    subplot(4,2,7); hold on; grid on;
    plot(t, e_psi, 'Color',[0.85 0.20 0.15], 'LineWidth',1.1);
    plot(t, A.geom.L_eff_m * kap * 180/pi, 'Color',[0.10 0.35 0.75], 'LineWidth',1.2);
    plot(t, beta, 'Color',[0.45 0.45 0.10], 'LineWidth',1.0);
    plot(t([1 end]), [3 3], 'k:','LineWidth',1.1);
    plot(t([1 end]), [LIM/A.code.Kp_psi LIM/A.code.Kp_psi], 'm--','LineWidth',1.2);
    xlabel('t [s]'); ylabel('deg');
    title(sprintf('7. Standing heading error is geometric: L_{eff}=%.3g m, L\\kappa=%.3g deg', ...
        A.geom.L_eff_m, A.geom.L_eff_m*A.geom.kappa_median*180/pi));
    legend({'e_\psi','L_{eff}\kappa (lookahead lead)','\beta (sideslip)','e_{\psi0}=3 deg g_{ac} corner', ...
        sprintf('e_\\psi that alone rails: %.3g deg', LIM/A.code.Kp_psi)}, 'Location','northwest','FontSize',6.5);

    % ---- 8: predeclared shadow anchors ----
    subplot(4,2,8); hold on; grid on;
    sv = [1, A.hyp.s_dp, A.hyp.s_env, A.hyp.s_unit];
    lbl = {'s=1 control','s_{dp} design point','s_{env} headroom','s_{unit} rad->deg'};
    raw_pk = sv * A.hyp.raw_absmax_deg;
    p_med  = sv * A.geom.P_observed_median;
    bar(1:4, [raw_pk(:) abs(p_med(:))], 0.8);
    plot([0.5 4.5], [LIM LIM], 'k--','LineWidth',1.4);
    plot([0.5 4.5], [A.geom.trim_req_deg A.geom.trim_req_deg], 'r-.','LineWidth',1.4);
    set(gca,'YScale','log','XTick',1:4,'XTickLabel',lbl,'FontSize',7);
    try; set(gca,'XTickLabelRotation',18); catch; end
    ylabel('deg'); ylim([1 1e3]);
    legend({'scaled raw peak','scaled |term_P| median', sprintf('%g deg envelope',LIM), ...
        sprintf('%.3g deg plant trim need',A.geom.trim_req_deg)},'Location','northeast','FontSize',6.5);
    title('8. Predeclared coordinated-sweep anchors (algebra on stored raw, NOT a prediction)');

    % ---- banner ----
    annotation(f,'textbox',[0.005 0.965 0.99 0.033], 'String', ...
        sprintf(['GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT_001  |  cell %s, frozen nominal, no resimulation  |  ' ...
                 'dimensional defects proved: %d  |  NO corrective candidate, coordinated shadow sweep declared  |  ' ...
                 'NOT_CERTIFIED, Gate9 LOCKED, no promotion'], R0.cell_name, A.n_dimensional_defects_proved), ...
        'EdgeColor','none','FontSize',8.5,'FontWeight','bold','HorizontalAlignment','center', ...
        'Interpreter','none');

    print(f, '-dpng', '-r150', png_path);
    close(f);
end
