function [evalout, elapsed] = heldout_rec(rec, mat, scoring, varargin)
% elapsed: training time and testing time.
[test, test_ratio, train_ratio, split_mode, times, topk, cutoff, rec_opt] = process_options(varargin, 'test', [], ...
    'test_ratio', 0.2, 'train_ratio', -1, 'split_mode', 'un', 'times', 1, 'topk', -1, 'cutoff', -1);
if train_ratio<0
    train_ratio = 1 - test_ratio;
end
assert(test_ratio >0 && test_ratio <1)
assert(train_ratio >0 && train_ratio <= 1 - test_ratio)
train_ratio = min(train_ratio, 1 - test_ratio);
if topk > 0 && cutoff > 0
    topk = cutoff;
elseif cutoff<=0
    if topk>0
        cutoff = topk;
    else
        cutoff = 200;
    end
end
elapsed = zeros(1,2);
if ~isempty(test)
    % recommendation for the given dataset
    train = mat;
    tic; [P, Q] = rec(train, rec_opt{:}); elapsed(1) = toc;
    tic; evalout = scoring(train, test, P,  Q, topk, cutoff); elapsed(2) = toc;
    if(nnz(test)>0) % Truth condition indicates regular evaluation returning struct  
        fns = fieldnames(evalout);
        for f=1:length(fns)
            fieldname = fns{f};
            field_mean = evalout.(fieldname);
            evalout.(fieldname) = [field_mean; zeros(1,length(field_mean))];
        end
    end
else
    % split mat and perform recommendation
    
    evalout = struct();
    for t=1:times
        [train, test] = split_matrix(mat, split_mode, 1-test_ratio);
        [train, ~] = split_matrix(train, split_mode, train_ratio/(1-test_ratio));
        tic; [P, Q] = rec(train, rec_opt{:}); elapsed(1) = elapsed(1) + toc/times;
        tic;
        if strcmp(split_mode, 'i')
            ind = sum(test)>0;
            metric_time = scoring(train(:,ind), test(:,ind), P,  Q(ind,:), topk, cutoff);
        else
            metric_time = scoring(train, test, P,  Q, topk, cutoff);
        end
        elapsed(2) = elapsed(2) + toc/times;
        fns = fieldnames(metric_time);
        for f=1:length(fns)
            fieldname = fns{f};
            if isfield(evalout, fieldname)
                evalout.(fieldname) = evalout.(fieldname) + [metric_time.(fieldname);(metric_time.(fieldname)).^2];
            else
                evalout.(fieldname) = [metric_time.(fieldname);(metric_time.(fieldname)).^2];
            end
        end
    end
    fns = fieldnames(evalout);
    for f=1:length(fns)
        fieldname = fns{f};
        field = evalout.(fieldname);
        field_mean = field(1,:) / times;
        field_std = sqrt(field(2,:)./times - field_mean .* field_mean);
        evalout.(fieldname) = [field_mean; field_std];
    end
end

end
