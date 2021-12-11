#!/usr/bin/env julia

# HOW TO RUN THIS SCRIPT:
# 1: check that you have a recent(ish, >1.0) version of Julia installed
# 2: within Julia, make sure you have the required packages (below, in the "Using..." statement) installed (I think they all come by default though)
# 3: make sure you have FFmpeg installed
# 4: setup an empty sub-directory called "tmpPlots"
# 5: go to line 693 and uncomment the `makeAnim()` function call
# 6: save this file
# 7: run this file (double click it and tell it to run with Julia, open a terminal and type `julia threeBodyProb.jl`, or start a julia session and type `include("threeBodyProb.jl")` )
# 8: profit

# following the above steps should generate a random three-body problem video in 720p without music
# to add music, specify initial conditions, or otherwise tinker...read the code/README and the comments in the code!
# this has only been tested on Linux (Mint) and Windows 10, so you might run into small additional issues on macOS?

using Plots, Random, Printf, Plots.Measures, Dates

function initCondGen() #get random initial conditions for mass/radius, position, and velocity
    function getMass(nBodies) #generate random masses that better reflect actual stellar populations, although not currently using because it's boring
        mList=zeros(nBodies)
        N=(0.5^(-1.3)-150^(-1.3))/1.3 #crude approximation of IMF integral assuming alpha = 2.3, stellar mass range of 0.5:150 solar masses
        rescale=1e6
        max=floor(Int,N*rescale)
        for i=1:nBodies
            intTarget=rand(0:max,1)[1]/rescale
            m=(0.5^(-1.3)-intTarget*1.3)^(-1/1.3) #just algebra from above
            mList[i]=round(m,digits=2)
        end
        return mList
    end
    m=rand(1:1500,3)./10 #3 random masses between 0.1 and 150 solar masses, uniform distribution
    #m=getMass(3) #get mass from IMF -- this way is kind of boring...so not using it, but left here in case I change my mind?
    #m=[15.5,7.3,13.1]
    rad=m.^0.8 #3 radii based on masses in solar units
    m=m.*2e30 #convert to SI kg

    rad=rad.*7e8 #convert to SI m
    pos1=rand(-25:25,2) #random initial coordinates x & y for first body, AU
    function genPos2(pos1)
        accept2=false
        while accept2==false
            pos2=rand(-25:25,2) #random initial coordinates for second body, AU
            dist21=sqrt((pos1[1]-pos2[1])^2+(pos1[2]-pos2[2])^2)
            if (dist21*1.5e11)>(rad[1]+rad[2]) #they aren't touching
                accept2=true
                return pos2
            end
        end
    end
    pos2=genPos2(pos1)
    function genPos3(pos1,pos2)
        accept3=false
        while accept3==false
            pos3=rand(-25:25,2) #random initial coordinates for third body, AU
            dist31=sqrt((pos1[1]-pos3[1])^2+(pos1[2]-pos3[2])^2)
            dist32=sqrt((pos2[1]-pos3[1])^2+(pos2[2]-pos3[2])^2)
            if (dist31*1.5e11)>(rad[1]+rad[3]) && (dist32*1.5e11)>(rad[2]+rad[3]) #3rd isn't touching either
                accept3=true
                return pos3
            end
        end
    end
    pos3=genPos3(pos1,pos2)
    pos=[pos1[1],pos1[2],pos2[1],pos2[2],pos3[1],pos3[2]].*1.5e11 #convert accepted positions to SI, m
    #pos=[-12,2,13,1,-2,-25].*1.5e11
    v=rand(-7e3:7e3,6) #random x & y velocities with mag between -10 & 10 km/s, totally arbitrary...
    #v=[2.922,-1.443,0.511,0.142,3.502,-1.255].*1e3
    #r=[x1,y1,x2,y2,x3,y3,v1x,v1y,v2x,v2y,v3x,v3y] -- format if you want to specify your own initial conditions
    r=[pos[1],pos[2],pos[3],pos[4],pos[5],pos[6],v[1],v[2],v[3],v[4],v[5],v[6]]
    open("initCond.txt","w") do f #save initial conditions to file in folder where script is run
        write(f,"m1=$(@sprintf("%.1f",(m[1]/2e30))) m2=$(@sprintf("%.1f",(m[2]/2e30))) m3=$(@sprintf("%.1f",(m[3]/2e30))) (solar masses)\nv1x=$(v[1]/1e3) v1y=$(v[2]/1e3) v2x=$(v[3]/1e3) v2y=$(v[4]/1e3) v3x=$(v[5]/1e3) v3y=$(v[6]/1e3) (km/s)\nx1=$(pos1[1]) y1=$(pos1[2]) x2=$(pos2[1]) y2=$(pos2[2]) x3=$(pos3[1]) y3=$(pos3[2]) (AU from center)")
    end
    return r, rad, m
end



function dR(r,m;energyBool=0) #function we will use RK4 on to approximate solution
    G=6.67408313131313e-11# Nm^2/kg^2
    M1,M2,M3=m[1],m[2],m[3] #kg
    x1,x2,x3=r[1],r[3],r[5] #m
    y1,y2,y3=r[2],r[4],r[6] #m

    c1,c2,c3=G*M1,G*M2,G*M3 #Nm^2/kg
    r1_2=sqrt((x1-x2)^2+(y1-y2)^2) #distance from 1->2, m
    r1_3=sqrt((x1-x3)^2+(y1-y3)^2) #distance from 1->3, m
    r2_3=sqrt((x2-x3)^2+(y2-y3)^2) #distance from 2->3, m

    v1X,v2X,v3X=r[7],r[9],r[11] #these are our change in position after dt (dr/dt*dt=dr)
    v1Y,v2Y,v3Y=r[8],r[10],r[12] #m after * dt

    #get change in velocity from accelerations (d^2r/dt^2*dt=dv/dt*dt=dv)
    aX1=-(c2*(x1-x2)/(r1_2^3))-(c3*(x1-x3)/(r1_3^3)) #d^2x/dt^2 for 1, m/s after * dt
    aX2=-(c1*(x2-x1)/(r1_2^3))-(c3*(x2-x3)/(r2_3^3)) #d^2x/dt^2 for 2, m/s
    aX3=-(c1*(x3-x1)/(r1_3^3))-(c2*(x3-x2)/(r2_3^3)) #d^2x/dt^2 for 3, m/s
    aY1=-(c2*(y1-y2)/(r1_2^3))-(c3*(y1-y3)/(r1_3^3)) #d^2y/dt^2 for 1, m/s
    aY2=-(c1*(y2-y1)/(r1_2^3))-(c3*(y2-y3)/(r2_3^3)) #d^2y/dt^2 for 2, m/s
    aY3=-(c1*(y3-y1)/(r1_3^3))-(c2*(y3-y2)/(r2_3^3)) #d^2y/dt^2 for 3, m/s

    global energy #keep track of energy loss from RK4 error
    U=-G*M1*M2/r1_2-G*M2*M3/r2_3-G*M1*M3/r1_3 #grav potential
    K=0.5*M1*(v1X^2+v1Y^2)+0.5*M2*(v2X^2+v2Y^2)+0.5*M3*(v3X^2+v3Y^2) #kinetic
    if energyBool==1
        push!(energy,K+U) #total system energy
    end

    return [v1X,v1Y,v2X,v2Y,v3X,v3Y,aX1,aY1,aX2,aY2,aX3,aY3]
end

function gen3Body(stopCond=[10,100],numSteps=10000) #default stop conditions of 10 yrs and 100 AU sep
    tStop=stopCond[1]*365*24*3600 #convert to SI s
    sepStop=stopCond[2]*1.5e11 #convert to SI m
    stop=false
    currentT=0
    t=range(0,stop=tStop,length=(numSteps+1)) #+1 because I don't want 0 to count
    stepSize=tStop/numSteps
    x1=zeros(length(t))
    y1=zeros(length(t))
    x2=zeros(length(t))
    y2=zeros(length(t))
    x3=zeros(length(t))
    y3=zeros(length(t))
    r,rad,m=initCondGen()
    initV=copy(r[7:end])
    min12=rad[1]+rad[2]
    min13=rad[1]+rad[3]
    min23=rad[2]+rad[3]
    i=1
    stopT=maximum(t)
    collisionBool=false; collisionInds=[0,0]
    #implement RK4 to model solutions to differential equations
    while stop==false
        if currentT==stopT || currentT>stopT #in case of rounding error or something
            stop=true
        elseif i>(numSteps+1) #inf loop failsafe
            stop=true
            println("error: shouldn't have gotten here")
        else
            x1[i]=r[1] #store current positions
            y1[i]=r[2]
            x2[i]=r[3]
            y2[i]=r[4]
            x3[i]=r[5]
            y3[i]=r[6]

            k1=stepSize*dR(r,m,energyBool=1)
            k2=stepSize*dR(r.+0.5.*k1,m)
            k3=stepSize*dR(r.+0.5.*k2,m)
            k4=stepSize*dR(r.+k3,m)
            r+=(k1.+2.0*k2.+2.0.*k3.+k4)./6 #RK4 update to positions, velocities

            #check separation after each dt step
            sep12=sqrt((x1[i]-x2[i])^2+(y1[i]-y2[i])^2)
            sep13=sqrt((x1[i]-x3[i])^2+(y1[i]-y3[i])^2)
            sep23=sqrt((x3[i]-x2[i])^2+(y3[i]-y2[i])^2)

            if sep12<min12 || sep13<min13 || sep23<min23 || sep12>sepStop || sep13>sepStop || sep23>sepStop
                if sep12<min12 || sep13<min13 || sep23<min23
                    collisionBool=true
                    if sep12<min12
                        collisionInds=[1,2]
                    elseif sep13<min13
                        collisionInds=[1,3]
                    elseif sep23<min23
                        collisionInds=[2,3]
                    end
                    stop = true
                else
                    G=6.67e-11
                    collisionBool=false
                    if sep12>sepStop && sep13>sepStop #1 is "ejected"
                        M = m[2] + m[3]
                        cmx = (m[2]*r[3]+m[3]*r[5])/M
                        cmy = (m[2]*r[4]+m[3]*r[6])/M
                        dist = sqrt((r[1]-cmx)^2+(r[2]-cmy)^2)
                        vEscape = sqrt(2*G*M/dist)
                        currentV = sqrt(r[7]^2+r[8]^2)
                        if currentV > vEscape
                            stop = true
                            println("1 ejected")
                        end
                    elseif sep23>sepStop && sep13>sepStop #3 is ejected
                        M = m[2] + m[1]
                        cmx = (m[2]*r[3]+m[1]*r[1])/M
                        cmy = (m[2]*r[4]+m[1]*r[2])/M
                        dist = sqrt((r[5]-cmx)^2+(r[6]-cmy)^2)
                        vEscape = sqrt(2*G*M/dist)
                        currentV = sqrt(r[11]^2+r[12]^2)
                        if currentV > vEscape
                            stop = true
                            println("3 ejected")
                        end
                    elseif sep23>sepStop && sep12>sepStop #2 is ejected
                        M = m[1] + m[3]
                        cmx = (m[1]*r[1]+m[3]*r[5])/M
                        cmy = (m[1]*r[2]+m[3]*r[6])/M
                        dist = sqrt((r[3]-cmx)^2+(r[4]-cmy)^2)
                        vEscape = sqrt(2*G*M/dist)
                        currentV = sqrt(r[9]^2+r[10]^2)
                        if currentV > vEscape
                            stop = true
                            println("2 ejected")
                        end
                    end
                end
                if stop==true #stop if collision happens or body is ejected
                    t=range(0,stop=currentT,length=i) #t should match pos vectors
                    x1=x1[1:i] #don't want trailing zeros
                    y1=y1[1:i]
                    x2=x2[1:i]
                    y2=y2[1:i]
                    x3=x3[1:i]
                    y3=y3[1:i]
                end
            end
            i+=1
            currentT+=stepSize #next step
        end
    end
    return [x1,y1,x2,y2,x3,y3], t, m, rad, collisionBool, collisionInds, initV
end

function getInteresting3Body(minTime=0) #in years, defaults to 0
    #sometimes (most of the time) random conditions result in a really short animation where things
    #just crash into each other/fly away, so this function throws away those
    yearSec=365*24*3600
    interesting=false
    i=1
    while interesting==false
        global energy=[] #re-initialize empty energy array
        plotData,t,m,rad,collisionBool,collisionInds,initV=gen3Body([60,100],600000)
        if (maximum(t)/yearSec)>minTime #only return if simulation runs for longer than minTime
            println(maximum(t)/yearSec) #tell me how many years we are simulating
            open("cron_log.txt","a") do f #for cron logging, a flag = append
                write(f,"$(maximum(t)/yearSec)\n")
            end
            open("3BodyStats.txt","a") do f #for stats logging
                initPos=[plotData[1][1],plotData[2][1],plotData[3][1],plotData[4][1],plotData[5][1],plotData[6][1]]./1.5e11 #AU
                write(f,"$(today()),$(maximum(t)/yearSec),$(m[1]/2e30),$(m[2]/2e30),$(m[3]/2e30),$(rad[1]/7e8),$(rad[2]/7e8),$(rad[3]/7e8),$collisionBool,$(collisionInds[1]),$(collisionInds[2]),$(initPos[1]),$(initPos[2]),$(initPos[3]),$(initPos[4]),$(initPos[5]),$(initPos[6]),$(initV[1]/1e3),$(initV[2]/1e3),$(initV[3]/1e3),$(initV[4]/1e3),$(initV[5]/1e3),$(initV[6]/1e3),$i\n")
            end
            return plotData,t,m,rad,collisionBool,collisionInds
            interesting=true
        elseif i>1999 #computationally expensive so don't want to go forever
            interesting=true #render it anyways I guess because sometimes it's fun?
            println("did not find interesting solution in number of tries allotted, running anyways")
            println(maximum(t)/yearSec) #how many years simulation runs for
            open("cron_log.txt","a") do f #for cron logging
                write(f,"found a solution with t = $(maximum(t)/yearSec) in $i iterations\n")
            end
            open("3BodyStats.txt","a") do f #log stats, see "3BodyAnalysis.ipynb"
                initPos=[plotData[1][1],plotData[2][1],plotData[3][1],plotData[4][1],plotData[5][1],plotData[6][1]]./1.5e11 #AU
                write(f,"$(today()),$(maximum(t)/yearSec),$(m[1]/2e30),$(m[2]/2e30),$(m[3]/2e30),$(rad[1]/7e8),$(rad[2]/7e8),$(rad[3]/7e8),$collisionBool,$(collisionInds[1]),$(collisionInds[2]),$(initPos[1]),$(initPos[2]),$(initPos[3]),$(initPos[4]),$(initPos[5]),$(initPos[6]),$(initV[1]/1e3),$(initV[2]/1e3),$(initV[3]/1e3),$(initV[4]/1e3),$(initV[5]/1e3),$(initV[6]/1e3),$i\n")
            end
            return plotData,t,m,rad,collisionBool,collisionInds
        end
        i+=1
    end
end

function detectOrbiting(d1_2,d1_3,d2_3,m,x,y) #determines if 2 bodies are orbiting, so we should use their center of mass for frame calculation
    if d1_2/d2_3 > 2 && d1_3/d2_3 > 2 #objects 2 and 3 are orbiting?
        orbiting=23
        cmX=(m[2]*x[2]+m[3]*x[3])/(m[2]+m[3]) #get centers of mass to use in limit calculations to prevent oscillations
        cmY=(m[2]*y[2]+m[3]*y[3])/(m[2]+m[3])
        xNew=[x[1],cmX]
        yNew=[y[1],cmY]
        return orbiting,xNew,yNew
    elseif d2_3/d1_2 > 2 && d1_3/d1_2 > 2 #objects 2 and 1 are orbiting?
        orbiting=21
        cmX=(m[2]*x[2]+m[1]*x[1])/(m[2]+m[1]) #get centers of mass
        cmY=(m[2]*y[2]+m[1]*y[1])/(m[2]+m[1])
        xNew=[x[3],cmX]
        yNew=[y[3],cmY]
        return orbiting,xNew,yNew
    elseif d1_2/d1_3 > 2 && d2_3/d1_3 > 2 #objects 1 and 3 are orbiting?
        orbiting=13
        cmX=(m[1]*x[1]+m[3]*x[3])/(m[1]+m[3]) #get centers of mass
        cmY=(m[1]*y[1]+m[3]*y[3])/(m[1]+m[3])
        xNew=[x[2],cmX]
        yNew=[y[2],cmY]
        return orbiting,xNew,yNew
    else #no pairs orbiting
        return 0,x,y
    end
end

function getLims(xNew,yNew,padding,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD) #computes limits given padding and offsets
    cX,cY=sum(xNew)/length(xNew),sum(yNew)/length(yNew) #next thing to change..?
    dx=maximum(xNew)-minimum(xNew); dy=maximum(yNew)-minimum(yNew)
    dF = dx<dy ? dy : dx #do we use dx or dy for the frame?
    xlims=[(cX+ΔCx)-padding-dF/2+ΔL,(cX+ΔCx)+padding+dF/2+ΔR]
    ylims=[(cY+ΔCy)-padding-dF/2+ΔD,(cY+ΔCy)+padding+dF/2+ΔU]
    return xlims,ylims
end

function getΔC(target,start,pos,extraDx,extraDy,x,y,padding,tol=0.0001,maxIter=100000) #find center shifts brute force
    targCx,targCy,targxlims,targylims = target #these are the "old" limits we want offset to
    cx,cy = start #from new limits
    ΔCx,ΔCy = cx-targCx,cy-targCy #initial "guess"
    diffxList = [0.,0.,0.]; diffyList = [0.,0.,0.]
    xtargList = [0.,0.,0.]; ytargList = [0.,0.,0.]
    ΔL,ΔR = extraDx; ΔU,ΔD = extraDy
    xlims,ylims = getLims(x,y,padding,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD)
    diff(r,rTarg)=abs(r-rTarg)
    for i = 1:length(pos)
        Bx,By = pos[i]
        rx,ry = relative(xlims,ylims,Bx,By) #where is it in terms of the frame width?
        rxTarg,ryTarg = relative(targxlims,targylims,Bx,By) #where was it? (where it should be)
        xtargList[i] = rxTarg; ytargList[i] = ryTarg
        diffxList[i] = diff(rx,rxTarg); diffyList[i] = diff(ry,ryTarg)
    end
    diffx,xInd = findmax(diffxList); diffy,yInd = findmax(diffyList) #find the one that shifted the most
    Bx = pos[xInd][1]; By = pos[yInd][2]
    rxTarg = xtargList[xInd]; ryTarg = ytargList[yInd]
    if diffx<tol && diffy<tol #not that big a difference, just return the initial guess
        return xlims,ylims,ΔCx,ΔCy
    else
        dx = targxlims[2]-targxlims[1]; dy = targylims[2]-targylims[1]
        function getDir(targxlims,targylims,ΔCx,ΔCy,tol,dx,dy) #figure out which way we need to shift
            acceptXDir = false; acceptYDir = false
            signdx = diffx<tol ? 0 : -1; signdy = diffy<tol ? 0 : -1
            counter = 1
            while acceptXDir == false || acceptYDir == false
                if acceptXDir == false
                    signdx=signdx^counter #flip the direction if what we tried before didn't work
                end
                if acceptYDir == false
                    signdy=signdy^counter
                end
                guessX = ΔCx+signdx*dx*tol/10; guessY = ΔCy+signdy*dy*tol/10
                xlims,ylims = getLims(x,y,padding,guessX,guessY,ΔL,ΔR,ΔU,ΔD)
                rx,ry = relative(xlims,ylims,Bx,By)
                newDiffx=diff(rx,rxTarg); newDiffy=diff(ry,ryTarg)
                acceptXDir = newDiffx<=diffx; acceptYDir = newDiffy<=diffy #are we going in the right direction?
                if counter>2
                    println("PROBLEM: changing center sign has no effect")
                    break
                end
                counter+=1
            end
            return signdx,signdy,guessX,guessY
        end
        signdx,signdy,guessX,guessY = getDir(targxlims,targylims,ΔCx,ΔCy,tol,dx,dy)
        counter = 2
        stopX = false; stopY = false
        while diffx>tol || diffy>tol #keep guessing in the right direction until we're within the tolerance
            #this could actaully probably just be calculated? whatever "if it ain't broke don't fix it" and
            #this is not high performance code
            if stopX == false
                guessX = ΔCx+signdx*dx*tol/10*counter
            end
            if stopY == false
                guessY = ΔCy+signdy*dy*tol/10*counter
            end
            xlims,ylims = getLims(x,y,padding,guessX,guessY,ΔL,ΔR,ΔU,ΔD)
            rx,ry = relative(xlims,ylims,Bx,By)
            diffx=diff(rx,rxTarg); diffy=diff(ry,ryTarg)
            stopX = diffx<tol; stopY = diffy<tol #compare new guesses and see if we should stop guessing
            counter+=1
            if counter == maxIter
                println("PROBLEM: did not converge in $maxIter iterations")
                break
            end
        end
        return xlims,ylims,guessX,guessY
    end
end

relative(xlims,ylims,x,y)=(x-xlims[1])/(xlims[2]-xlims[1]),(y-ylims[1])/(ylims[2]-ylims[1]) #returns position in terms of frame widths
center(xy) = sum(xy)/length(xy)

function comparePos(orbitOld,orbiting,m,x,y,padding,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD) #try to prevent jumps when switching modes
    orbitStr = orbiting!=0 ? string(orbiting) : string(orbitOld) #was the old one orbiting or is this one orbiting?
    i1,i2=parse(Int64,string(orbitStr[1])),parse(Int64,string(orbitStr[2])) #indices of two orbiting bodies
    inds = [1,2,3]; otherInd = 0 #trying to make generalization to n-bodies easier
    for i = 1:length(inds)
        if inds[i] != i1 && inds[i] != i2
            otherInd = i
        end
    end
    cmX=(m[i1]*x[i1]+m[i2]*x[i2])/(m[i1]+m[i2]) #get centers of mass
    cmY=(m[i1]*y[i1]+m[i2]*y[i2])/(m[i1]+m[i2])
    xNew=[x[otherInd],cmX] #new is a bit of a misnomer because sometimes it's old
    yNew=[y[otherInd],cmY] #point is we use this one for orbiting, the other for not
    xlimsOrbit,ylimsOrbit=getLims(xNew,yNew,padding,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD)
    xlimsNorm,ylimsNorm=getLims(x,y,padding,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD)
    function getOld(orbitOld,xlimsOrbit,ylimsOrbit,xlimsNorm,ylimsNorm,x,y,xNew,yNew) #which one was the old one?
        if orbitOld != 0 #thing was orbiting
            oldxlims,oldylims = xlimsOrbit,ylimsOrbit
            oldCx,oldCy = center(xNew),center(yNew)
            return oldxlims,oldylims,oldCx,oldCy
        else
            oldxlims,oldylims = xlimsNorm,ylimsNorm
            oldCx,oldCy = center(x),center(y)
            return oldxlims,oldylims,oldCx,oldCy
        end
    end
    oldxlims,oldylims,oldCx,oldCy = getOld(orbitOld,xlimsOrbit,ylimsOrbit,xlimsNorm,ylimsNorm,x,y,xNew,yNew)
    if orbiting != 0 #transitioning to orbiting, frame instantaneously wants to shrink
        cx = center(xNew); cy = center(yNew)
        ΔL = oldxlims[1]-xlimsOrbit[1]; ΔR = oldxlims[2]-xlimsOrbit[2]
        ΔU = oldylims[2]-ylimsOrbit[2]; ΔD = oldylims[1]-ylimsOrbit[1]
        extraDx = [ΔL,ΔR]; extraDy = [ΔU,ΔD]
        xlims,ylims,ΔCx,ΔCy = getΔC([oldCx,oldCy,oldxlims,oldylims],[cx,cy],[[x[1],y[1]],[x[2],y[2]],[x[3],y[3]]],extraDx,extraDy,xNew,yNew,padding)
        return xlims,ylims,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD
    else #transitioning from orbiting, frame instantaneously wants to expand
        cx = center(x); cy = center(y)
        ΔL = oldxlims[1]-xlimsNorm[1]; ΔR = oldxlims[2]-xlimsNorm[2]
        ΔU = oldylims[2]-ylimsNorm[2]; ΔD = oldylims[1]-ylimsNorm[1]
        extraDx = [ΔL,ΔR]; extraDy = [ΔU,ΔD]
        xlims,ylims,ΔCx,ΔCy = getΔC([oldCx,oldCy,oldxlims,oldylims],[cx,cy],[[x[1],y[1]],[x[2],y[2]],[x[3],y[3]]],extraDx,extraDy,x,y,padding)
        return xlims,ylims,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD
    end
end

function computeLimits(pos,posFuture,padding,m,orbitOld,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD) #determines plot limits at each frame, padding in units of pos
    x=[pos[1],pos[3],pos[5]]
    y=[pos[2],pos[4],pos[6]]
    d1_2=sqrt((x[1]-x[2])^2 + (y[1]-y[2])^2)
    d1_3=sqrt((x[1]-x[3])^2 + (y[1]-y[3])^2)
    d2_3=sqrt((x[2]-x[3])^2 + (y[2]-y[3])^2)
    orbiting,xNew,yNew = detectOrbiting(d1_2,d1_3,d2_3,m,x,y) #are they orbiting?
    if orbiting != orbitOld #are we switching modes?
        xlims,ylims,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD = comparePos(orbitOld,orbiting,m,x,y,padding,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD)
    else #"slowly" make the offsets go to zero, produces a nice smooth camera motion as we adjust
        relax = 0.95
        ΔCx*=relax;ΔCy*=relax;ΔL*=relax;ΔR*=relax;ΔU*=relax;ΔD*=relax
        xlims,ylims = getLims(xNew,yNew,padding,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD)
    end
    cNew = [(xlims[2]-xlims[1])/2+xlims[1],(ylims[2]-ylims[1])/2+ylims[1]] #dx+min(x); dy+min(y)
    return xlims,ylims,cNew,orbiting,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD
end


function getColors(m,c) #places colors of objects according to mass/size
    #c=[:biggest,:medium,:smallest] (order of input colors)
    maxM=maximum(m)
    minM=minimum(m)
    colors=[:blue,:blue,:blue] #testing
    if m[1]==maxM
        colors[1]=c[1]
        if m[2]==minM
            colors[2]=c[3]
            colors[3]=c[2]
        else
            colors[3]=c[3]
            colors[2]=c[2]
        end
    elseif m[2]==maxM
        colors[2]=c[1]
        if m[1]==minM
            colors[1]=c[3]
            colors[3]=c[2]
        else
            colors[3]=c[3]
            colors[1]=c[2]
        end
    else
        colors[3]=c[1]
        if m[1]==minM
            colors[1]=c[3]
            colors[2]=c[2]
        else
            colors[2]=c[3]
            colors[1]=c[2]
        end
    end
    return colors
end

function makeCircleVals(r,center=[0,0]) #makes circle values for the stars to plot
    xOffset=center[1]
    yOffset=center[2]
    xVals=[r*cos(i)+xOffset for i=0:(pi/64):(2*pi)]
    yVals=[r*sin(i)+yOffset for i=0:(pi/64):(2*pi)]
    return xVals,yVals
end

function main() #pulls everything together, speeds things up to put everything in a function + gets rid of bad global syntax
    println("sit tight -- finding an interesting solution")
    plotData,t,m,rad,collisionBool,collisionInds=getInteresting3Body(15) #find an interesting solution at least 15 years
    if collisionBool == true
        println("collision! inds = $collisionInds")
    else
        println("no collision")
    end

    c=[:DodgerBlue,:Gold,:Tomato] #most massive to least massive, also roughly corresponds to temp
    colors=getColors(m,c)
    #adding fake stars
    numStars=2500
    starsX=zeros(numStars)
    starsY=zeros(numStars)
    for i=1:numStars
        num=rand(-200:200,2) #box size is 70 AU but we need some extra padding for movement
        starsX[i]=num[1]
        starsY[i]=num[2]
    end

    function getRatioRight(ratio,dx,dy) #makes sure the frame matches the ratio we want (for Twitter, square)
        if (dx/dy)!=ratio
            if dx>(ratio*dy)
                dy=dx/ratio
            else
                dx=dy*ratio
            end
        end
        return dx,dy
    end

    function relative(p::Plots.Subplot, rx, ry) #so I can plot in relative to parent
       xlims=Plots.xlims(p)
       ylims=Plots.ylims(p)
       return xlims[1]+rx*(xlims[2]-xlims[1]), ylims[1]+ry*(ylims[2]-ylims[1])
    end

    frameNum=1 #initialize frame counter
    stop=length(t) #what index the end is
    if collisionBool==true
        stop=length(t)-600 #-600 because we want to do the last 600 frames in slo-mo
    end
    #initialize a bunch of other things we'll need
    listInd=0
    limList=[]
    ratio=1
    offsetX = [0.,0.]; offsetY = [0.,0.]
    orbitOld = 0
    center = [0.,0.]; vel = [0.,0.]
    ΔCx = 0.;ΔCy = 0.;ΔL = 0.;ΔR = 0.;ΔU = 0.;ΔD = 0.
    println("energy loss = $((energy[end]-energy[1])/energy[1]*100) %") #anecdotally this is usually very small, but occasionally gets as high as ~1%
    for i=1:333:stop #this makes animation scale ~1 sec/year with other conditions
        GR.inline("png") #added to eneable cron/jobber compatibility, also this makes frames generate WAY faster? Prior to adding this when run from cron/jobber frames would stop generating at 408 for some reason.
        gr(legendfontcolor = plot_color(:white)) #legendfontcolor=:white plot arg broken right now (at least in this backend)
        print("$(@sprintf("%.2f",i/length(t)*100)) % complete\r") #output percent tracker
        pos=[plotData[1][i],plotData[2][i],plotData[3][i],plotData[4][i],plotData[5][i],plotData[6][i]] #current pos
        future = i+500<stop ? i+500 : i #make sure we don't go past end of data
        posFuture=[plotData[1][future],plotData[2][future],plotData[3][future],plotData[4][future],plotData[5][future],plotData[6][future]] #future pos
        limx,limy,center,orbitOld,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD=computeLimits(pos./1.5e11,posFuture./1.5e11,15,m,orbitOld,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD) #compute limits in AU, 15 AU padding
        dx,dy=(limx[2]-limx[1]),(limy[2]-limy[1])
        dx,dy=getRatioRight(ratio,dx,dy) #check ratio
        if listInd>1
            oldLimx,oldLimy=limList[listInd][1],limList[listInd][2]
            oldDx,oldDy=oldLimx[2]-oldLimx[1],oldLimy[2]-oldLimy[1]
            maxContraction=0.98; maxExpansion=1.02
            if dx/oldDx<maxContraction #frame shrunk more than x%
                limx[1]=center[1]-oldDx*maxContraction/2
                limx[2]=center[1]+oldDx*maxContraction/2
                limy[1]=center[2]-oldDx*maxContraction/2
                limy[2]=center[2]+oldDx*maxContraction/2
            elseif dx/oldDx>maxExpansion #grew more than x%
                limx[1]=center[1]-oldDx*maxExpansion/2
                limx[2]=center[1]+oldDx*maxExpansion/2
                limy[1]=center[2]-oldDx*maxExpansion/2
                limy[2]=center[2]+oldDx*maxExpansion/2
            elseif dy/oldDy<maxContraction #shrunk more than y%
                limx[1]=center[1]-oldDy*maxContraction/2
                limx[2]=center[1]+oldDy*maxContraction/2
                limy[1]=center[2]-oldDy*maxContraction/2
                limy[2]=center[2]+oldDy*maxContraction/2
            elseif dy/oldDy>maxExpansion #grew more than y%
                limx[1]=center[1]-oldDy*maxExpansion/2
                limx[2]=center[1]+oldDy*maxExpansion/2
                limy[1]=center[2]-oldDy*maxExpansion/2
                limy[2]=center[2]+oldDy*maxExpansion/2
            end
        end
        listInd+=1
        dx,dy=(limx[2]-limx[1]),(limy[2]-limy[1])
        dx,dy=getRatioRight(ratio,dx,dy) #check again
        limx = [center[1]-dx/2,center[1]+dx/2]; limy = [center[2]-dy/2,center[2]+dy/2]
        push!(limList,[limx,limy]) #record limits for later use, push! is bad and we should just preallocate this but whatever
        p=plot(plotData[1][1:33:i]./1.5e11,plotData[2][1:33:i]./1.5e11,label="",linewidth=2,linecolor=colors[1],linealpha=max.((1:33:i) .+ 10000 .- i,2500)/10000) #plot orbits up to i
        p=plot!(plotData[3][1:33:i]./1.5e11,plotData[4][1:33:i]./1.5e11,label="",linewidth=2,linecolor=colors[2],linealpha=max.((1:33:i) .+ 10000 .- i,2500)/10000) #linealpha argument causes lines to decay
        p=plot!(plotData[5][1:33:i]./1.5e11,plotData[6][1:33:i]./1.5e11,label="",linewidth=2,linecolor=colors[3],linealpha=max.((1:33:i) .+ 10000 .- i,2500)/10000) #example: alpha=max.((1:i) .+ 100 .- i,0) causes only last 100 to be visible
        p=scatter!(starsX,starsY,markercolor=:white,markersize=:1,label="") #fake background stars
        star1=makeCircleVals(rad[1],[plotData[1][i],plotData[2][i]]) #generate circles with appropriate sizes for each star
        star2=makeCircleVals(rad[2],[plotData[3][i],plotData[4][i]]) #at current positions
        star3=makeCircleVals(rad[3],[plotData[5][i],plotData[6][i]])
        p=plot!(star1[1]./1.5e11,star1[2]./1.5e11,label="$(@sprintf("%.1f", m[1]./2e30))",color=colors[1],fill=true) #plot star circles with labels
        p=plot!(star2[1]./1.5e11,star2[2]./1.5e11,label="$(@sprintf("%.1f", m[2]./2e30))",color=colors[2],fill=true)
        p=plot!(star3[1]./1.5e11,star3[2]./1.5e11,label="$(@sprintf("%.1f", m[3]./2e30))",color=colors[3],fill=true)
        p=plot!(background_color=:black,background_color_legend=:transparent,foreground_color_legend=:transparent,
            background_color_outside=:white,aspect_ratio=:equal,legendtitlefontcolor=:white,legendfontfamily="Courier") #formatting for plot frame
        p=plot!(xlabel="x: AU",ylabel="y: AU",title="Random Three-Body Problem\nt:      years after start",
            legend=:best,xaxis=("x: AU",(limx[1],limx[2]),font(9,"Courier")),yaxis=("y: AU",(limy[1],limy[2]),font(9,"Courier")),tickfontcolor=:white,
            grid=false,titlefont=font(14,"Courier"),size=(720,721),legendfontsize=8,legendtitle="Mass (in solar masses)",legendtitlefontsize=8,legendtitlefont="Courier") #add in axes/title/legend with formatting

        tX,tY=relative(p[1],0.3,1.044)#static coords for time relative to parent
        p = annotate!(tX,tY,Plots.text((@sprintf("%0.2f",t[i]/365/24/3600)),"Courier",14,"black"))
        png(p,@sprintf("tmpPlots/frame_%06d.png",frameNum))
        frameNum+=1
        closeall() #close plots
    end

    if collisionBool==true #this condition makes 2 seconds of slo-mo right before the collision
        println("making collision cam")
        for i=1:10:600
            GR.inline("png") #added to eneable cron/jobber compatibility, also this makes frames generate WAY faster? Prior to adding this when run from cron/jobber frames would stop generating at 408 for some reason.
            gr(legendfontcolor = plot_color(:white)) #legendfontcolor=:white plot arg broken right now (at least in this backend)
            print("$(@sprintf("%.2f",i/600*100)) % complete\r") #output percent tracker
            pos=[plotData[1][end-(600-i)],plotData[2][end-(600-i)],plotData[3][end-(600-i)],plotData[4][end-(600-i)],plotData[5][end-(600-i)],plotData[6][end-(600-i)]] #current pos
            posFuture=pos #don't need future position at end
            limx,limy,center,orbitOld,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD=computeLimits(pos./1.5e11,posFuture./1.5e11,15,m,orbitOld,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD) #convert to AU, 10 AU padding
            p=plot(plotData[1][1:33:end-(600-i)]./1.5e11,plotData[2][1:33:end-(600-i)]./1.5e11,label="",linecolor=colors[1],linewidth=2,linealpha=max.((1:33:(i+length(t)-600)) .+ 10000 .- (i+length(t)-600),2500)/10000) #plot orbits up to i
            p=plot!(plotData[3][1:33:end-(600-i)]./1.5e11,plotData[4][1:33:end-(600-i)]./1.5e11,label="",linecolor=colors[2],linewidth=2,linealpha=max.((1:33:(i+length(t)-600)) .+ 10000 .- (i+length(t)-600),2500)/10000) #linealpha argument causes lines to decay
            p=plot!(plotData[5][1:33:end-(600-i)]./1.5e11,plotData[6][1:33:end-(600-i)]./1.5e11,label="",linecolor=colors[3],linewidth=2,linealpha=max.((1:33:(i+length(t)-600)) .+ 10000 .- (i+length(t)-600),2500)/10000) #example: alpha=max.((1:i) .+ 100 .- i,0) causes only last 100 to be visible
            p=scatter!(starsX,starsY,markercolor=:white,markersize=:1,label="") #fake background stars
            star1=makeCircleVals(rad[1],[plotData[1][end-(600-i)],plotData[2][end-(600-i)]]) #generate circles with appropriate sizes for each star
            star2=makeCircleVals(rad[2],[plotData[3][end-(600-i)],plotData[4][end-(600-i)]]) #at current positions
            star3=makeCircleVals(rad[3],[plotData[5][end-(600-i)],plotData[6][end-(600-i)]])
            p=plot!(star1[1]./1.5e11,star1[2]./1.5e11,label="$(@sprintf("%.1f", m[1]./2e30))",color=colors[1],fill=true) #plot star circles with labels
            p=plot!(star2[1]./1.5e11,star2[2]./1.5e11,label="$(@sprintf("%.1f", m[2]./2e30))",color=colors[2],fill=true)
            p=plot!(star3[1]./1.5e11,star3[2]./1.5e11,label="$(@sprintf("%.1f", m[3]./2e30))",color=colors[3],fill=true)
            p=plot!(background_color=:black,background_color_legend=:transparent,foreground_color_legend=:transparent,
                background_color_outside=:white,aspect_ratio=:equal,legendtitlefontcolor=:white,legendfontfamily="Courier") #formatting for plot frame
            p=plot!(xlabel="x: AU",ylabel="y: AU",title="Random Three-Body Problem\nt: $(@sprintf("%0.2f",t[end-(600-i)]/365/24/3600)) years after start",
                legend=:best,xaxis=("x: AU",(limx[1],limx[2]),font(9,"Courier")),yaxis=("y: AU",(limy[1],limy[2]),font(9,"Courier")),
                grid=false,titlefont=font(14,"Courier"),size=(720,721),legendfontsize=8,legendtitle="Mass (in solar masses)",legendtitlefontsize=8,legendtitlefont="Courier") #add in axes/title/legend with formatting
            #collision cam zoom in
            i1,i2=collisionInds #these are the ones that are colliding, we use them to set the frame limits
            X=[plotData[1][end-(600-i)],plotData[3][end-(600-i)],plotData[5][end-(600-i)]]./1.5e11; Y=[plotData[2][end-(600-i)],plotData[4][end-(600-i)],plotData[6][end-(600-i)]]./1.5e11
            minX=(min(X[i1],X[i2])-1); maxX=(max(X[i1],X[i2])); minY=(min(Y[i1],Y[i2])-1); maxY=(max(Y[i1],Y[i2]))
            dx=maxX-minX; dy=maxY-minY
            dF=dx<dy ? dy : dx #use dy for frame if dx smaller, else dx

            #draw zoom box
            cornersX=[minX,minX+dF+1]; cornersY=[minY,minY+dF+1]
            p=plot!([cornersX[1],cornersX[2]],[cornersY[1],cornersY[1]],c=:white,label="") #side 1
            p=plot!([cornersX[2],cornersX[2]],[cornersY[1],cornersY[2]],c=:white,label="") #side 2
            p=plot!([cornersX[1],cornersX[2]],[cornersY[2],cornersY[2]],c=:white,label="") #side 3
            p=plot!([cornersX[1],cornersX[1]],[cornersY[1],cornersY[2]],c=:white,label="") #side 4
            offset = 0.0145 #for some reason the x corners don't quite match...
            s1x,s1y = relative(p[1],1/8-offset,7/8-0.25); s2x,s2y = relative(p[1],1/8+0.25-offset,7/8)
            subCornersX=[s1x,s2x]; subCornersY=[s1y,s2y] #physical coordinates, box in top left
            p=plot!([subCornersX[1],cornersX[1]],[subCornersY[1],cornersY[1]],c=:white,label = "") #corner 1 -> corner 1
            p=plot!([subCornersX[2],cornersX[2]],[subCornersY[2],cornersY[2]],c=:white,label = "") #corner 2 -> corner 2
            p=plot!([subCornersX[1],cornersX[1]],[subCornersY[2],cornersY[2]],c=:white,label = "") #corner 3 -> corner 3
            p=plot!([subCornersX[2],cornersX[2]],[subCornersY[1],cornersY[1]],c=:white,label = "") #corner 4 -> corner 4
            #draw box before plot so plot labels are on top
            p=plot!(title="COLLISION CAM\n(slo-mo x 33)",titlefontcolor=:orange,inset=(1,bbox(1/8,1/8,0.25,0.25)),
                    xlims=(minX,minX+dF+1),ylims=(minY,minY+dF+1),legend=:false,left_margin=0mm,right_margin=0mm,top_margin=0mm,bottom_margin=0mm,
                    foreground_color_border=:white,foreground_color_axis=:white,foreground_color_text=:white,grid=:false,
                    aspect_ratio=:equal,fontfamily=:Courier,subplot=2,framestyle=:box,titlefontsize=10,tickfontsize=6)
            p=plot!(p[2],plotData[1][1:10:end-(600-i)]./1.5e11,plotData[2][1:10:end-(600-i)]./1.5e11,label="",linecolor=colors[1],linewidth=2,linealpha=max.((1:10:(i+length(t)-600)) .+ 10000 .- (i+length(t)-600),2500)/10000)
            p=plot!(p[2],plotData[3][1:10:end-(600-i)]./1.5e11,plotData[4][1:10:end-(600-i)]./1.5e11,label="",linecolor=colors[2],linewidth=2,linealpha=max.((1:10:(i+length(t)-600)) .+ 10000 .- (i+length(t)-600),2500)/10000)
            p=plot!(p[2],plotData[5][1:10:end-(600-i)]./1.5e11,plotData[6][1:10:end-(600-i)]./1.5e11,label="",linecolor=colors[3],linewidth=2,linealpha=max.((1:10:(i+length(t)-600)) .+ 10000 .- (i+length(t)-600),2500)/10000)
            p=plot!(p[2],star1[1]./1.5e11,star1[2]./1.5e11,color=colors[1],fill=true)
            p=plot!(p[2],star2[1]./1.5e11,star2[2]./1.5e11,color=colors[2],fill=true)
            p=plot!(p[2],star3[1]./1.5e11,star3[2]./1.5e11,color=colors[3],fill=true)
            p=scatter!(p[2],starsX,starsY,markercolor=:white,markersize=:1,label="") #fake background stars
            #save frame
            png(p,@sprintf("tmpPlots/frame_%06d.png",frameNum))
            frameNum+=1
            closeall() #close plots
        end
        println("making freeze frame ending")
        for i=1:15 #make 0.5 s freeze frame ending
            GR.inline("png") #added to eneable cron/jobber compatibility, also this makes frames generate WAY faster? Prior to adding this when run from cron/jobber frames would stop generating at 408 for some reason.
            gr(legendfontcolor = plot_color(:white)) #legendfontcolor=:white plot arg broken right now (at least in this backend)
            print("$(@sprintf("%.2f",i/15*100)) % complete\r") #output percent tracker
            pos=[plotData[1][end],plotData[2][end],plotData[3][end],plotData[4][end],plotData[5][end],plotData[6][end]] #current pos
            posFuture=pos #don't need future position at end
            limx,limy,center,orbitOld,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD=computeLimits(pos./1.5e11,posFuture./1.5e11,15,m,orbitOld,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD) #convert to AU, 10 AU padding
            p=plot(plotData[1][1:33:end]./1.5e11,plotData[2][1:33:end]./1.5e11,label="",linecolor=colors[1],linewidth=2,linealpha=max.((1:33:(length(t))) .+ 10000 .- (length(t)),2500)/10000) #plot orbits up to i
            p=plot!(plotData[3][1:33:end]./1.5e11,plotData[4][1:33:end]./1.5e11,label="",linecolor=colors[2],linewidth=2,linealpha=max.((1:33:(length(t))) .+ 10000 .- (length(t)),2500)/10000) #linealpha argument causes lines to decay
            p=plot!(plotData[5][1:33:end]./1.5e11,plotData[6][1:33:end]./1.5e11,label="",linecolor=colors[3],linewidth=2,linealpha=max.((1:33:(length(t))) .+ 10000 .- (length(t)),2500)/10000) #example: alpha=max.((1:i) .+ 100 .- i,0) causes only last 100 to be visible
            p=scatter!(starsX,starsY,markercolor=:white,markersize=:1,label="") #fake background stars
            star1=makeCircleVals(rad[1],[plotData[1][end],plotData[2][end]]) #generate circles with appropriate sizes for each star
            star2=makeCircleVals(rad[2],[plotData[3][end],plotData[4][end]]) #at current positions
            star3=makeCircleVals(rad[3],[plotData[5][end],plotData[6][end]])
            p=plot!(star1[1]./1.5e11,star1[2]./1.5e11,label="$(@sprintf("%.1f", m[1]./2e30))",color=colors[1],fill=true) #plot star circles with labels
            p=plot!(star2[1]./1.5e11,star2[2]./1.5e11,label="$(@sprintf("%.1f", m[2]./2e30))",color=colors[2],fill=true)
            p=plot!(star3[1]./1.5e11,star3[2]./1.5e11,label="$(@sprintf("%.1f", m[3]./2e30))",color=colors[3],fill=true)
            p=plot!(background_color=:black,background_color_legend=:transparent,foreground_color_legend=:transparent,
                background_color_outside=:white,aspect_ratio=:equal,legendtitlefontcolor=:white,legendfontfamily="Courier") #formatting for plot frame
            p=plot!(xlabel="x: AU",ylabel="y: AU",title="Random Three-Body Problem\nt: $(@sprintf("%0.2f",t[end]/365/24/3600)) years after start",
                legend=:best,xaxis=("x: AU",(limx[1],limx[2]),font(9,"Courier")),yaxis=("y: AU",(limy[1],limy[2]),font(9,"Courier")),
                grid=false,titlefont=font(14,"Courier"),size=(720,721),legendfontsize=8,legendtitle="Mass (in solar masses)",legendtitlefontsize=8,legendtitlefont="Courier") #add in axes/title/legend with formatting
            #collision cam zoom in
            i1,i2=collisionInds #these are the ones that are colliding, we use them to set the frame limits
            X=[plotData[1][end],plotData[3][end],plotData[5][end]]./1.5e11; Y=[plotData[2][end],plotData[4][end],plotData[6][end]]./1.5e11
            minX=(min(X[i1],X[i2])-1); maxX=(max(X[i1],X[i2])); minY=(min(Y[i1],Y[i2])-1); maxY=(max(Y[i1],Y[i2]))
            dx=maxX-minX; dy=maxY-minY
            dF=dx<dy ? dy : dx #use dy for frame if dx smaller, else dx

            p=plot!(title="COLLISION CAM\n(slo-mo x 33)",titlefontcolor=:orange,inset=(1,bbox(1/8,1/8,0.25,0.25)),
                    xlims=(minX,minX+dF+1),ylims=(minY,minY+dF+1),legend=:false,left_margin=0mm,right_margin=0mm,top_margin=0mm,bottom_margin=0mm,
                    foreground_color_border=:white,foreground_color_axis=:white,foreground_color_text=:white,grid=:false,
                    aspect_ratio=:equal,fontfamily=:Courier,subplot=2,framestyle=:box,titlefontsize=10,tickfontsize=6)
            p=plot!(p[2],plotData[1][1:10:end]./1.5e11,plotData[2][1:10:end]./1.5e11,label="",linecolor=colors[1],linewidth=2,linealpha=max.((1:10:(length(t))) .+ 10000 .- (length(t)),2500)/10000)
            p=plot!(p[2],plotData[3][1:10:end]./1.5e11,plotData[4][1:10:end]./1.5e11,label="",linecolor=colors[2],linewidth=2,linealpha=max.((1:10:(length(t))) .+ 10000 .- (length(t)),2500)/10000)
            p=plot!(p[2],plotData[5][1:10:end]./1.5e11,plotData[6][1:10:end]./1.5e11,label="",linecolor=colors[3],linewidth=2,linealpha=max.((1:10:(length(t))) .+ 10000 .- (length(t)),2500)/10000)
            p=plot!(p[2],star1[1]./1.5e11,star1[2]./1.5e11,color=colors[1],fill=true)
            p=plot!(p[2],star2[1]./1.5e11,star2[2]./1.5e11,color=colors[2],fill=true)
            p=plot!(p[2],star3[1]./1.5e11,star3[2]./1.5e11,color=colors[3],fill=true)
            p=scatter!(p[2],starsX,starsY,markercolor=:white,markersize=:1,label="") #fake background stars
            #draw zoom box
            cornersX=[minX,minX+dF+1]; cornersY=[minY,minY+dF+1]
            p=plot!([cornersX[1],cornersX[2]],[cornersY[1],cornersY[1]],c=:white,label="") #side 1
            p=plot!([cornersX[2],cornersX[2]],[cornersY[1],cornersY[2]],c=:white,label="") #side 2
            p=plot!([cornersX[1],cornersX[2]],[cornersY[2],cornersY[2]],c=:white,label="") #side 3
            p=plot!([cornersX[1],cornersX[1]],[cornersY[1],cornersY[2]],c=:white,label="") #side 4
            offset = 0.0145 #for some reason the x corners don't quite match...
            s1x,s1y = relative(p[1],1/8-offset,7/8-0.25); s2x,s2y = relative(p[1],1/8+0.25-offset,7/8)
            subCornersX=[s1x,s2x]; subCornersY=[s1y,s2y] #physical coordinates, box in top left
            p=plot!([subCornersX[1],cornersX[1]],[subCornersY[1],cornersY[1]],c=:white,label = "") #corner 1 -> corner 1
            p=plot!([subCornersX[2],cornersX[2]],[subCornersY[2],cornersY[2]],c=:white,label = "") #corner 2 -> corner 2
            p=plot!([subCornersX[1],cornersX[1]],[subCornersY[2],cornersY[2]],c=:white,label = "") #corner 3 -> corner 3
            p=plot!([subCornersX[2],cornersX[2]],[subCornersY[1],cornersY[1]],c=:white,label = "") #corner 4 -> corner 4
            #save frame
            png(p,@sprintf("tmpPlots/frame_%06d.png",frameNum))
            frameNum+=1
            closeall() #close plots
        end
    end
end

#this is a function that will generate the animation for you without having to use the command line, works on Linux and Windows (run as administrator), untested on macOS
function makeAnim(clean=true)
    run(`ffmpeg -framerate 30 -i "tmpPlots/frame_%06d.png" -c:v libx264 -preset slow -coder 1 -movflags +faststart -g 15 -crf 18 -pix_fmt yuv420p -profile:v high -y -bf 2 -vf "scale=720:720,setdar=1/1" "threeBody.mp4"`)
    if clean==true
        println("cleaning up png files")
        foreach(rm,[string("tmpPlots/",x) for x in filter(endswith(".png"),readdir("tmpPlots"))])
    end
end



#generate frames!
main()

#generate the animation!
#makeAnim() #commented out because I compile the frames in the shell script (see 3BodyShell.sh)

#you'll want to uncomment the line above to tell the script to just make the animation
#or you can load the script into a julia terminal with include("threeBodyProb.jl")
#and then call main() and makeAnim() to your heart's content

#OLD STUFF....

#threeBodyFile="3Body_fps30.mp4"

#crf is compression value (17 or 18 "visually lossless"), pix_fmt is for twitter specific vid req, -b:v specifies target bitrate, -vcodec specifies codec (h264 in this case) -y says overwrite existing file
#run( `ffmpeg -framerate 30 -i $plotLoadPath"%06d.png" -vcodec libx264 -pix_fmt yuv420p -profile:v high -b:v 2048K -y -vf "scale=720:720,setdar=1/1" $threeBodyFile` ) #-vf scale=720:72 -crf 25
#run( `ffmpeg -framerate 30 -i $plotLoadPath"%06d.png" -c:v libx264 -preset slow -coder 1 -movflags +faststart -g 15 -crf 18 -pix_fmt yuv420p -profile:v high -y -bf 2 -vf "scale=720:720,setdar=1/1" $threeBodyFile` ) #all this bullshit to hopefully satisfy twitter requirements

#NOTE: moved ffmpeg commands to shell script

#old (simpler) way of generating animation
#uncomment and use this way if you just want a simple animation saved and don't
#care about performance/specific formatting of video.

# threeBodyAnim=@animate for i=1:length(t)
#     gr(legendfontcolor = plot_color(:white)) #plot arg broken right now in Julia
#     print("$(@sprintf("%.2f",i/length(t)*100)) % complete\r") #output percent tracker
#     pos=[plotData[1][i],plotData[2][i],plotData[3][i],plotData[4][i],plotData[5][i],plotData[6][i]] #current pos
#     limx,limy,center=getLims(pos./1.5e11,5) #convert to AU, 5 AU padding
#     plot(plotData[1][1:i]./1.5e11,plotData[2][1:i]./1.5e11,label="",linecolor=colors[1])
#     plot!(plotData[3][1:i]./1.5e11,plotData[4][1:i]./1.5e11,label="",linecolor=colors[2])
#     plot!(plotData[5][1:i]./1.5e11,plotData[6][1:i]./1.5e11,label="",linecolor=colors[3])
#     scatter!(starsX,starsY,markercolor=:white,markersize=:1,label="") #fake background stars
#     star1=makeCircleVals(rad[1],[plotData[1][i],plotData[2][i]])
#     star2=makeCircleVals(rad[2],[plotData[3][i],plotData[4][i]])
#     star3=makeCircleVals(rad[3],[plotData[5][i],plotData[6][i]])
#     plot!(star1[1]./1.5e11,star1[2]./1.5e11,label="$(@sprintf("%.1f", m[1]./2e30))",color=colors[1],fill=true)
#     plot!(star2[1]./1.5e11,star2[2]./1.5e11,label="$(@sprintf("%.1f", m[2]./2e30))",color=colors[2],fill=true)
#     plot!(star3[1]./1.5e11,star3[2]./1.5e11,label="$(@sprintf("%.1f", m[3]./2e30))",color=colors[3],fill=true)
#     plot!(background_color=:black,background_color_legend=:transparent,background_color_outside=:white,aspect_ratio=:equal,legendtitlefontcolor=:white) #legendfontcolor=:white
#     plot!(xlabel="x: AU",ylabel="y: AU",title="Random Three Body Problem\nt: $(@sprintf("%0.2f",t[i]/365/24/3600)) yrs after start",
#         legend=:best,xaxis=("x: AU",(limx[1],limx[2]),font(12,"Courier")),yaxis=("y: AU",(limy[1],limy[2]),font(12,"Courier")),
#         grid=false,titlefont=font(24,"Courier"),size=(720,720),legendfontsize=12,legendtitle="Mass (in solar masses)",legendtitlefontsize=14)
#     end every 25

#mp4(threeBodyAnim,"3Body_fps30.mp4",fps=30)
#OR
#gif(threeBodyAnim,"3Body_fps30.gif",fps=30)
