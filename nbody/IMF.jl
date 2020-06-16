#!/usr/bin/env julia
using Random
function getMass(nBodies)
    mList=zeros(nBodies)
    N=(1.5^(-1.3)-150^(-1.3))/1.3 #crude approximation of IMF integral assuming alpha = 2.3, stellar mass range of 0.5:150 solar masses
    rescale=1e6
    max=floor(Int,N*rescale)
    for i=1:nBodies
        intTarget=rand(0:max,1)[1]/rescale
        m=(1.5^(-1.3)-intTarget*1.3)^(-1/1.3) #just algebra from above
        mList[i]=round(m,digits=2)
    end
    return mList
end
