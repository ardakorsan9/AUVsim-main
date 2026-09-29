function gate8_fig_qa(R, A, png_path)
% Self-documenting visual QA panel: gate table, determination table and the
% predeclared shadow gates, rendered so the figure itself carries the evidence.

    LN = {};   % {text, fontsize, weight, colour}
    LN = gate8_add(LN, 'GATE8_R10_YAW_TERM_DIMENSIONAL_CONSISTENCY_AUDIT_001 - visual QA and gate evidence', 11, 'bold', [0 0 0]);
    LN = gate8_add(LN, sprintf('verdict %s   |   hard gates %d/%d   |   dimensional defects proved %d   |   NOT_CERTIFIED, Gate9 LOCKED, no promotion', ...
        R.verdict, sum([R.gates.pass]), numel(R.gates), A.n_dimensional_defects_proved), 9, 'bold', [0.15 0.15 0.15]);
    LN = gate8_add(LN, '', 4, 'normal', [1 1 1]);

    LN = gate8_add(LN, 'HARD GATES', 9.5, 'bold', [0 0 0.55]);
    for k = 1:numel(R.gates)
        if R.gates(k).pass; tag = 'PASS'; c = [0 0.45 0.1]; else; tag = 'FAIL'; c = [0.75 0 0]; end
        LN = gate8_add(LN, sprintf('  %-5s %s  %s', R.gates(k).id, tag, gate8_trunc(R.gates(k).req, 148)), 7.2, 'normal', c);
        LN = gate8_add(LN, sprintf('            %s', gate8_trunc(R.gates(k).detail, 148)), 6.5, 'normal', [0.4 0.4 0.4]);
    end
    LN = gate8_add(LN, '', 4, 'normal', [1 1 1]);

    LN = gate8_add(LN, 'DETERMINATIONS - one class per audited item', 9.5, 'bold', [0 0 0.55]);
    for k = 1:numel(R.determinations)
        LN = gate8_add(LN, sprintf('  [%-32s] %s', R.determinations(k).determination, ...
            gate8_trunc(R.determinations(k).item, 108)), 7.0, 'normal', [0.1 0.1 0.1]);
    end
    LN = gate8_add(LN, '', 4, 'normal', [1 1 1]);

    LN = gate8_add(LN, 'PREDECLARED PROMOTION GATES FOR THE COORDINATED SHADOW SWEEP - nothing is promoted here', 9.5, 'bold', [0 0 0.55]);
    for k = 1:numel(R.shadow.gates)
        LN = gate8_add(LN, sprintf('  %-5s %s', R.shadow.gates(k).id, gate8_trunc(R.shadow.gates(k).req, 152)), 6.9, 'normal', [0.1 0.1 0.1]);
    end
    LN = gate8_add(LN, '', 4, 'normal', [1 1 1]);

    LN = gate8_add(LN, 'VISUAL QA CHECKS', 9.5, 'bold', [0 0 0.55]);
    for k = 1:numel(R.visual_qa.checks)
        if R.visual_qa.checks(k).pass; tag = 'PASS'; c = [0 0.45 0.1]; else; tag = 'FAIL'; c = [0.75 0 0]; end
        LN = gate8_add(LN, sprintf('  %s %-34s %s', tag, R.visual_qa.checks(k).name, ...
            gate8_trunc(R.visual_qa.checks(k).detail, 100)), 6.9, 'normal', c);
    end
    for k = 1:numel(R.visual_qa.files)
        LN = gate8_add(LN, sprintf('  file %-70s %7.1f KiB  %dx%d px  ok=%d', ...
            R.visual_qa.files(k).path, R.visual_qa.files(k).kib, R.visual_qa.files(k).width, ...
            R.visual_qa.files(k).height, R.visual_qa.files(k).ok), 6.5, 'normal', [0.4 0.4 0.4]);
    end

    f = figure('Visible','off','Color','w','Units','inches','Position',[0.5 0.5 13.5 10.5]);
    set(f,'PaperPositionMode','auto');
    ax = axes('Parent',f,'Position',[0.015 0.01 0.975 0.975]);
    axis(ax,'off'); hold(ax,'on'); xlim(ax,[0 1]); ylim(ax,[0 1]);

    n = size(LN,1);
    dy = 0.985 / max(n,1);
    for k = 1:n
        yk = 0.992 - (k-1)*dy;
        text(ax, 0.006, yk, LN{k,1}, 'FontSize', LN{k,2}, 'FontWeight', LN{k,3}, ...
            'Color', LN{k,4}, 'Interpreter','none', 'VerticalAlignment','top', 'FontName','Courier New');
    end

    print(f, '-dpng', '-r150', png_path);
    close(f);
end

function LN = gate8_add(LN, s, sz, wt, c)
    LN(end+1, :) = {s, sz, wt, c};
end

function s = gate8_trunc(s, n)
    s = regexprep(s, '\s+', ' ');
    if numel(s) > n
        s = [s(1:max(n-3,1)) '...'];
    end
end
