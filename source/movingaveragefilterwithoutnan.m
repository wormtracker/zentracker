function result = movingaveragefilterwithoutnan (data, number)
    result = NaN(size(data));
    
    lookdifference = floor((number-1)/2);

    for i=max([lookdifference+1 1]):numel(data)-max([lookdifference 0])
        result(i) = nanmean(data(i-lookdifference:i+lookdifference));
    end

end