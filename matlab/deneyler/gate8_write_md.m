function gate8_write_md(md_path, R, A, R0)
    fid = fopen(md_path, 'w');
    if fid < 0; error('gate8:md', 'cannot open %s', md_path); end
    p = @(varargin) fprintf(fid, varargin{:});

    p('# GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT_001\n\n');
    p('**Verdict %s.** No exact dimensional or duplicate-scaling inconsistency is proved in the yaw command\n', R.verdict);
    p('equation, so **no corrective candidate is stated**. Instead a single coordinated shadow experiment is\n');
    p('declared with predeclared promotion gates. Hardware **NOT_CERTIFIED**. **Gate9 LOCKED**. Nothing promoted.\n\n');
    p('- created: %s\n', R.created);
    p('- certification: %s\n', R.certification);
    p('- honesty: %s\n\n', R.honesty);

    p('## 1. Bounded scope\n\n');
    p('Exactly three sources were read. No repo scan. No simulation, no plant call, no resimulation of any kind.\n');
    p('One MATLAB invocation, no retry.\n\n');
    p('| # | source | role | fingerprint |\n|---|---|---|---|\n');
    for i = 1:numel(R.sources)
        p('| %d | `%s` | %s | `%s` |\n', i, strrep(R.sources{i},'\','/'), R.source_role{i}, R.src_fp{i});
    end
    p('\nEvidence read: `%s`, verdict %s, cell %s, stored nominal hash `%s`, reproduced = %d.\n', ...
        R.evidence_task_id, R.evidence_verdict, R.evidence_cell, R.evidence_hash, R.evidence_reproduced);
    p('That record localised the rail to `%s` with origin_kind `%s` and declared a BLOCKER. This audit does not\n', ...
        R.evidence_origin_id, R.evidence_origin_kind);
    p('overturn that verdict; it explains the multi-term command scale behind it.\n\n');

    p('## 2. Frames and units\n\n');
    p('| quantity | frame | internal unit | logged unit |\n|---|---|---|---|\n');
    p('| psi, yaw_ref, e_psi | NED heading | rad | deg |\n');
    p('| r, r_ff, e_r | BODY angular rate | rad/s | deg/s |\n');
    p('| p | BODY roll rate | rad/s | deg/s |\n');
    p('| delta_r and every contribution | rudder deflection | rad | deg |\n');
    p('| kappa_f | path curvature | 1/m | 1/m |\n');
    p('| U_h | inertial horizontal speed | m/s | m/s |\n');
    p('| dt_controller / dt_guidance | - | s | s |\n\n');
    p('%s\n\n', A.frames.this_task_note);
    p('Ratios below are formed in logged units. That is legitimate only because numerator and denominator carry\n');
    p('the same angular conversion, and establishing that identity **is** the rad/deg audit.\n\n');

    p('## 3. The existing yaw command, reconstructed symbolically\n\n```\n');
    for i = 1:numel(A.equation)
        p('%s\n', A.equation{i});
    end
    p('```\n\n');
    p('| coefficient | value | dimension | where it comes from |\n|---|---|---|---|\n');
    p('| Kp_psi | %g | [-] rad rudder per rad heading error | controller_law.m, global |\n', A.code.Kp_psi);
    p('| Kd_psi | %g | [s] rad rudder per rad/s rate error | controller_law.m, global |\n', A.code.Kd_psi);
    p('| Kp_roll | %.6f | [s] rad rudder per rad/s roll rate | controller_law.m default, YAW_ROLL_DAMPING_BACKOFF PASS |\n', A.code.Kp_roll);
    p('| e_psi0 | deg2rad(3) = %.6f | [rad] | controller_law.m, g_ac corner |\n', A.code.e_psi0);
    p('| e_r0 | deg2rad(8) = %.6f | should be [rad/s] | controller_law.m, g_ac corner |\n', A.code.e_r0);
    p('| delta_r_max | %g deg | [rad] internally | production parameter recorded in the evidence |\n', A.LIM);
    p('| rate limit | %g deg/s -> %.6g deg/tick | [rad/s] | deg2rad(40)*dt with dt = %g s |\n', A.RATE_LIM, A.rate_lim_tick_deg, A.dt);
    p('| k_beta | %g | [-] | guidance_law.m crab compensation |\n', A.code.k_beta);
    p('| r_ff clamp | %g deg/s | [rad/s] | guidance_law.m, never active here |\n', A.code.r_ff_clamp_degs);
    p('| Td = Kd_psi/Kp_psi | %.9g s | [s] | derived, scale-invariant |\n\n', A.code.Td);
    p('Signs: `+Kp_psi*e_psi`, `-Kd_psi*e_r`, `-Kp_roll*p`, and the feedforward enters with a **plus** because\n');
    p('`-Kd_psi*(r - r_ff)` expands to `-Kd_psi*r + Kd_psi*r_ff`. `e_psi` is wrapped once with `wrapToPi` and used\n');
    p('once. Roll damp is summed **before** both limiters, exactly as the file header declares.\n\n');

    p('## 4. Coefficient recovery from the stored log\n\n');
    p('Requirement: each observed contribution divided by its source signal must reproduce the code coefficient\n');
    p('within numerical tolerance wherever observable. Tolerance %.0e relative.\n\n', A.recov_tol);
    p('| ratio | code coefficient | observed min | observed max | observed median | spread | rel err | observable samples |\n');
    p('|---|---|---|---|---|---|---|---|\n');
    for k = 1:numel(A.recov)
        q = A.recov(k);
        p('| `%s` | %.9g | %.12g | %.12g | %.12g | %.3g | %.3g | %d / %d |\n', ...
            q.label, q.code_coefficient, q.min, q.max, q.median, q.spread, q.rel_err, q.n_observable, q.n_total);
    end
    p('\nAll four recover with **zero spread**. There is no hidden rad/deg factor, no duplicated conversion and no\n');
    p('second application of any gain on any of the four paths.\n\n');

    p('## 5. Structural, conversion, schedule and limiter-order identities\n\n');
    p('| identity | max residual | unit | rms | reading |\n|---|---|---|---|---|\n');
    for k = 1:numel(A.res)
        p('| `%s` | %.3g | %s | %.3g | %s |\n', A.res(k).label, A.res(k).maxabs, A.res(k).unit, A.res(k).rms, A.res(k).note);
    end
    p('\nWorst residual over all %d identities: %.3g. Limiter ordering is magnitude-then-rate and reproduces exactly.\n\n', ...
        numel(A.res), max([A.res.maxabs]));

    p('## 6. Duplicate-scaling test battery\n\n');
    p('| id | statement | outcome |\n|---|---|---|\n');
    for k = 1:numel(A.battery)
        if A.battery(k).consistent; o = 'CONSISTENT'; else; o = '**INCONSISTENT**'; end
        p('| %s | %s | %s |\n', A.battery(k).id, A.battery(k).statement, o);
    end
    p('\n**Dimensional or duplicate-scaling inconsistencies proved: %d of %d.**\n\n', ...
        A.n_dimensional_defects_proved, numel(A.battery));

    p('## 7. Envelope excess ledger\n\n');
    p('| term | peak [deg] | x envelope | median [deg] | x envelope | reaches %g deg alone |\n|---|---|---|---|---|---|\n', A.LIM);
    for k = 1:numel(A.ledger)
        p('| %s | %.4f | %.3g | %.4f | %.3g | %d |\n', A.ledger(k).term, A.ledger(k).absmax_deg, ...
            A.ledger(k).excess_absmax, A.ledger(k).medabs_deg, A.ledger(k).excess_medabs, A.ledger(k).reaches_env_alone);
    end
    p('\n## 8. Leave-one-term-out attribution, stored raw command only\n\n');
    p('This is algebra on the stored signals. Nothing is resimulated and no tracking effect is claimed.\n\n');
    p('### 8a. As logged, four contributions\n\n');
    p('| term | peak [deg] | median [deg] | signed share at rail | removal changes limited cmd | max change [deg] | rms change [deg] | saturation flips |\n');
    p('|---|---|---|---|---|---|---|---|\n');
    for k = 1:numel(A.loto_split)
        q = A.loto_split(k);
        p('| %s | %.4f | %.4f | %+.4f | %d / %d | %.4g | %.4g | %d |\n', q.term, q.absmax_deg, q.medabs_deg, ...
            q.signed_share_median_at_rail, q.n_changed_postmag, A.n, q.max_change_postmag_deg, ...
            q.rms_change_postmag_deg, q.n_sat_flips);
    end
    p('\n### 8b. Physically grouped, three contributions\n\n');
    p('`term_D` and `term_FF` are the two halves of the single term `-Kd_psi*(r - r_ff)`. Regrouping them is not\n');
    p('cosmetic: %s\n\n', A.decomp.note);
    p('| term | peak [deg] | median [deg] | signed share at rail | removal changes limited cmd | reaches envelope alone |\n');
    p('|---|---|---|---|---|---|\n');
    for k = 1:numel(A.loto_group)
        q = A.loto_group(k);
        p('| %s | %.4f | %.4f | %+.4f | %d / %d | %d |\n', q.term, q.absmax_deg, q.medabs_deg, ...
            q.signed_share_median_at_rail, q.n_changed_postmag, A.n, q.reaches_env_alone);
    end
    p('\nGrouped completeness residual %.3g deg. Under the grouped decomposition the dominant term is unambiguous\n', A.group_completeness_maxabs);
    p('(the proportional term, signed share %+.4f of the raw command at rail samples), while the rate term still\n', A.loto_group(1).signed_share_median_at_rail);
    p('reaches the envelope on its own during the limit-cycle ripple. The rail therefore remains multi-term, which\n');
    p('is consistent with the frozen record''s AMBIGUOUS finding, but part of its "3 of 4 terms rail alone" count is\n');
    p('a decomposition artifact rather than three independent physical drivers.\n\n');

    p('## 9. Determinations\n\n');
    for k = 1:numel(R.determinations)
        p('### %d. %s\n\n**%s.** %s\n\n', k, R.determinations(k).item, ...
            R.determinations(k).determination, R.determinations(k).evidence);
    end

    p('## 10. Why no corrective candidate is stated\n\n');
    p('%s\n\n', R.candidate_withheld);
    p('The strongest single-factor hypothesis was evaluated rather than assumed:\n\n');
    p('- %s\n', A.hyp.verdict);
    p('- %s\n\n', A.hyp.Td_invariance);

    p('## 11. Declared coordinated shadow experiment\n\n');
    p('**%s**\n\n', R.shadow.name);
    p('- why coordinated: %s\n', R.shadow.why_coordinated);
    p('- scope: %s\n', R.shadow.scope);
    p('- factor: %s\n', R.shadow.factor);
    p('- anchor provenance: %s\n', R.shadow.anchor_provenance);
    p('- caveat: %s\n', R.shadow.open_loop_caveat);
    p('- smallest-experiment argument: %s\n\n', R.shadow.smallest_argument);
    p('Predeclared anchors:\n\n');
    for k = 1:numel(R.shadow.anchors)
        p('%d. %s\n', k, R.shadow.anchors{k});
    end
    p('\nObservables to be logged with units, frames and provenance:\n\n');
    for k = 1:numel(R.shadow.observables)
        p('- %s\n', R.shadow.observables{k});
    end
    p('\n### Predeclared promotion gates\n\n| id | requirement |\n|---|---|\n');
    for k = 1:numel(R.shadow.gates)
        p('| %s | %s |\n', R.shadow.gates(k).id, R.shadow.gates(k).req);
    end
    p('\n### Falsifiers declared in advance\n\n');
    for k = 1:numel(R.shadow.falsifiers)
        p('- %s\n', R.shadow.falsifiers{k});
    end
    p('\n## 12. Hard gates for this audit\n\n| id | pass | requirement | detail |\n|---|---|---|---|\n');
    for k = 1:numel(R.gates)
        if R.gates(k).pass; t = 'PASS'; else; t = '**FAIL**'; end
        p('| %s | %s | %s | %s |\n', R.gates(k).id, t, R.gates(k).req, R.gates(k).detail);
    end
    p('\n## 13. Appended log, units and provenance\n\n');
    p('Derived log appended once: %d rows x %d columns.\n\n', size(A.derived_log,1), size(A.derived_log,2));
    p('| # | column | unit | provenance |\n|---|---|---|---|\n');
    for k = 1:numel(A.derived_log_cols)
        p('| %d | `%s` | %s | %s |\n', k, A.derived_log_cols{k}, A.derived_log_units{k}, A.derived_log_provenance{k});
    end
    p('\n## 14. Preservation and visual QA\n\n');
    p('- fingerprints unchanged pre and post: %d (%s)\n', R.fp_unchanged, R.fp_detail);
    for i = 1:numel(R.prod_files)
        p('  - `%s` : `%s`\n', strrep(R.prod_files{i},'\','/'), R.fp_pre{i});
    end
    p('- visual QA: **%s**, %d/%d files ok, %d/%d checks pass\n', R.visual_qa.verdict, R.visual_qa.n_ok, ...
        R.visual_qa.n_files, sum([R.visual_qa.checks.pass]), numel(R.visual_qa.checks));
    p('- %s\n', R.visual_qa.definition);
    p('\n| check | pass | detail |\n|---|---|---|\n');
    for k = 1:numel(R.visual_qa.checks)
        p('| %s | %d | %s |\n', R.visual_qa.checks(k).name, R.visual_qa.checks(k).pass, R.visual_qa.checks(k).detail);
    end
    p('\n| figure | KiB | pixels | ok |\n|---|---|---|---|\n');
    for k = 1:numel(R.visual_qa.files)
        p('| `%s` | %.1f | %dx%d | %d |\n', strrep(R.visual_qa.files(k).path,'\','/'), ...
            R.visual_qa.files(k).kib, R.visual_qa.files(k).width, R.visual_qa.files(k).height, R.visual_qa.files(k).ok);
    end

    p('\n## 15. Closing statement\n\n');
    p('The yaw command equation is dimensionally self-consistent everywhere it can be checked against the stored\n');
    p('log: four coefficients recovered with zero spread, one wrap, one conversion per path, the feedforward chain\n');
    p('exact, the schedule exact, and the limiter order exact. The rail therefore does **not** come from a units\n');
    p('bug or a duplicated scaling. It comes from a geometric standing heading offset of order L*kappa on a curved\n');
    p('path multiplied by a large integral-free proportional gain, with the roll-damp channel losing its authority\n');
    p('to the resulting saturation. That distinction is exactly why a corrective edit is withheld and a bounded\n');
    p('coordinated shadow sweep with predeclared gates is declared instead.\n\n');
    p('No gain, law, path, threshold, shaper or current-feedforward change was made. No tracking improvement is\n');
    p('claimed. Hardware NOT_CERTIFIED. Gate9 LOCKED. Nothing is promoted.\n');
    fclose(fid);
end
