#!/usr/bin/env julia
using JSON, Printf, Plots, Plots.Measures, Dates

#INSTRUCTIONS on using this code:
# 1: check that you have a recent(ish, >1.0) version of Julia installed
# 2: within Julia, make sure you have the required packages (above, in the "Using..." statement) installed (I think all but JSON comes by default?)
# 3: make sure you have FFmpeg installed
# 4: setup an empty sub-directory called "tmpPlots"
# 5: go to the bottom of this file and uncomment the makeAnim() function call (remove the #)
# 6: save this file
# 7: run this file (double click it and tell it to run with Julia, open a terminal and type: julia threeBodyProb.jl, or start a julia session in the same directory as the file and type: include("threeBodyProb.jl") )
# 8: have fun!!!

# NOTE: if you've come here from the tutorial video, the script has changed significantly since that was made, but luckily the process is still the same!
# to generate a random three-body animation with the same parameters as the bot would the process above still works, as do all the setup steps in the video.
# if you want to specify your own initial conditions you'll have to poke around in the code and change some things in initCondGen -- i.e. have it return your hard-coded conditions instead of randomly generating them
# in the future I'll add an interactive option that makes this clearer, but hopefully you can figure it out!
# you can change the length of the animation, the max acceptable error, the gravitational constant, minimum time, etc. by changing the call to getData at the top of the main() function in the plotting section
# i.e. to get a simulation with max duration of 120s you would change it from getData(3) to getData(3,maxTime=120). Full options and defaults documented at the top of getData function in the simulation section.
# I'll eventually make a new video showing this better next time I have free time -- sorry for inconvenience
# If you can't get it to work and want the file to match the video, download and use the LEGACYthreeBodyProb.jl file on the GitHub, as that file should be pretty much exactly the same as the one I used while making tutorial video!

############################## SIMULATION SECTION ###################################################

function initCondGen(nBodies; vRange=[-7e3,7e3],posRange=[-35,35],tweet=nothing) #get random initial conditions for mass/radius, position, and velocity, option for user to specify acceptable vRange and posRange
    if tweet == nothing
        m = rand(1:1500,nBodies)./10
        rad=m.^0.8 #3 radii based on masses in solar units
        m=m.*2e30 #convert to SI kg
        rad=rad.*7e8 #convert to SI m
        minV,maxV=vRange[1],vRange[2] #defaults to +/- 7km/s
        minPos,maxPos=posRange[1],posRange[2] #defaults to pos within 70 AU box
        posList=[]
        function checkPos(randPos,n,posList,rad) #this function checks if positions are too close to each other
            for i=2:(n-1)
                dist=sqrt((posList[i][1]-randPos[1])^2+(posList[i][2]-randPos[2])^2)
                if (dist*1.5e11)<(rad[n]+rad[i])
                    return false
                end
            end
            return true
        end
        function genPos(nBodies,posList,rad,minPos,maxPos) #this function generates random initial positions for all the bodies
            push!(posList,rand(minPos:maxPos,2)) #random initial x,y coords for 1st body, default 70 AU box width
            for n=2:nBodies
                acceptPos=false
                while acceptPos==false
                    randPos=rand(minPos:maxPos,2) #random guess
                    acceptPos=checkPos(randPos,n,posList,rad) #check if our random guess is okay
                    if acceptPos==true
                        push!(posList,randPos) #add accepted guess to master list
                    end
                end
            end
            return posList
        end
        pos=genPos(nBodies,posList,rad,minPos,maxPos).*1.5e11 #convert to SI, m
        coords = [zeros(nBodies),zeros(nBodies),zeros(nBodies),zeros(nBodies)] #x,y,vx,vy
        v = []
        for i=1:nBodies
            coords[1][i] = pos[i][1]
            coords[2][i] = pos[i][2]
            V = rand(minV:maxV,2)
            push!(v,V)
            coords[3][i] = V[1]
            coords[4][i] = V[2]
        end

        open("initCondAll.txt","w") do f #save initial conditions to file in folder where script is run
           for n=1:nBodies
               write(f,"body $n info: m = $(@sprintf("%.1f",(m[n]/2e30))) solar masses | v = ($(v[n][1]/1e3),$(v[n][2]/1e3)) km/s | starting position = ($(pos[n][1]/1.5e11),$(pos[n][2]/1.5e11)) AU from center\n")
           end
        end
        open("initCond.txt","w") do f
            for n=1:nBodies
                write(f,"m$n = $(@sprintf("%.1f",(m[n]/2e30)))\n")
            end
        end
        return m,rad,coords
    else #this only works on my machine using the bot's twitter authentication tokens. files not on GitHub, allows me to replicate simulation from tweet for easier making of extended editions!
        tweetID = split(tweet,"/")[end]
        run(`getTweetJSON.sh $tweetID`)
        s = readlines("TweetJSON.txt")
        j = JSON.parse(s[1])
        bodySplit = split(j["data"]["text"],"\n")
        mline = bodySplit[2]; vLine = bodySplit[3]; posLine = bodySplit[4]
        mSplit = split(mline," "); vSplit = split(vLine, " "); posSplit = split(posLine, " ")
        m = [parse(Float64,split(s,"=")[2]) for s in mSplit[1:3]]
        v = [parse(Float64,split(s,"=")[2]) for s in vSplit[1:6]].*1e3
        pos = [parse(Float64,split(s,"=")[2]) for s in posSplit[1:6]].*1.5e11
        coords = [pos[1:2:end],pos[2:2:end],v[1:2:end],v[2:2:end]]
        rad = m.^0.8
        m = m.*2e30
        rad = rad.*7e8
        return m,rad,coords
    end
end

function Δr(coords,masses,nBodies,G) #function we will use RK4 on to approximate solution
    x,y,vx,vy = deepcopy(coords) #in Julia saying a = b just sets pointers by default, this creates a physical copy in memory
    Δ = deepcopy(coords)
    for n=1:nBodies
        xn = x[n]; yn = y[n]
        Δvx = 0.; Δvy = 0.
        for i=1:nBodies #generalizing for later n-body problem
            if i!=n #only calculate if not self
                sep = sqrt((xn-x[i])^2+(yn-y[i])^2) #euclidean distance
                Δvx -= G*masses[i]*(xn - x[i])/sep^3 #change in velocity from each mass on mass n
                Δvy -= G*masses[i]*(yn - y[i])/sep^3
            end
        end
        Δ[3][n] = Δvx #change in velocity = a*dt
        Δ[4][n] = Δvy
    end
    Δ[1] = vx #change in position = v*dt
    Δ[2] = vy
    return Δ
end

function step!(coords,masses,Δt,nBodies=3,G=6.67408313131313e-11) #1 RK4 step for each body's coordinates, mutates coords
    k1 = Δt.*Δr(coords,masses,nBodies,G)
    k2 = Δt.*Δr(coords .+ k1./2,masses,nBodies,G)
    k3 = Δt.*Δr(coords .+ k2./2,masses,nBodies,G)
    k4 = Δt.*Δr(coords .+ k3,masses,nBodies,G)
    coords .+= (k1 .+ 2.0.*k2 .+ 2.0.*k3 .+ k4)./6
    return coords #return changes in position and velocity
end

function detectOrbiting(d1_2,d1_3,d2_3,m,x,y,ratio=2) #determines if 2 bodies are orbiting, so we should use their center of mass for frame calculation
    if d1_2/d2_3 > ratio && d1_3/d2_3 > ratio #objects 2 and 3 are orbiting?
        orbiting=23
        cmX=(m[2]*x[2]+m[3]*x[3])/(m[2]+m[3]) #get centers of mass to use in limit calculations to prevent oscillations
        cmY=(m[2]*y[2]+m[3]*y[3])/(m[2]+m[3])
        xNew=[x[1],cmX]
        yNew=[y[1],cmY]
        return orbiting,xNew,yNew
    elseif d2_3/d1_2 > ratio && d1_3/d1_2 > ratio #objects 2 and 1 are orbiting?
        orbiting=21
        cmX=(m[2]*x[2]+m[1]*x[1])/(m[2]+m[1]) #get centers of mass
        cmY=(m[2]*y[2]+m[1]*y[1])/(m[2]+m[1])
        xNew=[x[3],cmX]
        yNew=[y[3],cmY]
        return orbiting,xNew,yNew
    elseif d1_2/d1_3 > ratio && d2_3/d1_3 > ratio #objects 1 and 3 are orbiting?
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

d(coords,i1,i2) = sqrt((coords[1][i1]-coords[1][i2])^2+(coords[2][i1]-coords[2][i2])^2)

function detectCollisionsEscape(coords,masses,Δt,maxSep,G,R=nothing) #this tells us if two bodies have "collided" or one has "escaped"
    x,y,vx,vy = coords
    V = sqrt.(vx.^2 .+ vy.^2)
    R = R == nothing ? V.*Δt : R #if radii not supplies use v * timestep as simple estimate
    collision = false; collisionInds = nothing; escape = false; escapeInd = nothing
    for n=1:length(x)
        rn = R[n]; xn = x[n]; yn = y[n]
        for i=1:length(x)
            if i!=n #don't check if we collided with ourselves!
                minSep = rn+R[i]
                sep = √((xn-x[i])^2+(yn-y[i])^2)
                if sep<minSep #collision!
                    collision = true
                    collisionInds = n,i
                    return collision,collisionInds,escape,escapeInd
                elseif sep>maxSep #check for escape!
                    orbiting, throw = detectOrbiting(d(coords,1,2),d(coords,1,3),d(coords,2,3),masses,x,y)
                    orbitStr = string(orbiting)
                    if occursin(string(n),orbitStr)
                        i1,i2 = parse(Int,orbitStr[1]),parse(Int,orbitStr[2])
                        for i=1:3
                            if i != i1 && i != i2
                                n = i
                            end
                        end
                    end
                    CMX = sum(masses[1:end .!= n].*x[1:end .!= n])/sum(masses[1:end .!= n])
                    CMY = sum(masses[1:end .!= n].*y[1:end .!= n])/sum(masses[1:end .!= n])
                    CMDist = sqrt((x[n]-CMX)^2+(y[n]-CMY)^2)
                    V = sqrt(vx[n]^2+vy[n]^2)
                    vEsc = sqrt(2*G*sum(masses[1:end .!= n])/CMDist)*1.1 #*1.1 for some wiggle room since this is approximate
                    if V >= vEsc
                        escape = true
                        escapeInd = n
                    end
                    return collision,collisionInds,escape,escapeInd
                end
            end
        end
    end
    return collision,collisionInds,escape,escapeInd
end

function nBodyStep!(coords,masses,Δt,maxSep,nBodies,G=6.67408313131313e-11,R=nothing) #similar to our step function before, but keeping track of collisions
    coords = step!(coords,masses,Δt,nBodies,G) #update the positions as we did before
    collision,collisionInds,escape,escapeInd = detectCollisionsEscape(coords,masses,Δt,maxSep,G,R) #detect collisions/escapes
    if collision == true #do inelastic collision and delete extra body (2 -> 1)
        i1,i2 = collisionInds
        x1,x2 = coords[1][i1],coords[1][i2]
        y1,y2 = coords[2][i1],coords[2][i2]
        vx1,vx2 = coords[3][i1],coords[3][i2]
        vy1,vy2 = coords[4][i1],coords[4][i2]
        px1,px2 = masses[i1]*vx1,masses[i2]*vx2
        py1,py2 = masses[i1]*vy1,masses[i2]*vy2
        px = px1+px2
        py = py1+py2
        newM = masses[i1]+masses[i2]
        vfx = px/newM
        vfy = py/newM
        coords[1][i1] = (x1*masses[i1]+x2*masses[i2])/(masses[i1]+masses[i2]) #center of mass
        coords[2][i1] = (y1*masses[i1]+y2*masses[i2])/(masses[i1]+masses[i2])
        coords[3][i1] = vfx
        coords[4][i1] = vfy
        deleteat!(coords[1],i2); deleteat!(coords[2],i2); deleteat!(coords[3],i2); deleteat!(coords[4],i2)
        masses[i1] = newM
        deleteat!(masses,i2)
        if R != nothing
            R[i1] = 2*G*newM/9e16
            deleteat!(R,i2)
        end
        nBodies-=1
    end
    if R != nothing
    #could also implement condition for escape where we stop calculating forces but I'm too lazy for now
        return coords,masses,R,nBodies,collision,collisionInds,escape,escapeInd
    else
        return coords,masses,nBodies,collision,collisionInds,escape,escapeInd
    end
end

function getData(nBodies; totalETol = 1e-5, maxIter = 1000, maxTime=60,minYrs=15,tweet=nothing,custom=false,maxSep=150,G=6.67408313131313e-11) #currently only implemented for 3 bodies
    plotPts = maxTime*10000; EframeTol = totalETol/10000 #10000 gives scaling of ~1 sec per plot frame
    yearSec = 365*24*3600
    m,rad,coords = zeros(nBodies), zeros(nBodies), [zeros(nBodies),zeros(nBodies),zeros(nBodies),zeros(nBodies)]
    coordsRecord = [deepcopy(coords) for i=1:plotPts]
    T = zeros(plotPts)
    ΔtInit = maxTime*yearSec/plotPts #initial Δt, but can change based on orbiting
    Δt = deepcopy(ΔtInit)
    speedRecord = ones(plotPts)
    interesting = false; iter = 1; mStart = m; radStart = rad; nBodiesStart = nBodies
    while interesting == false && iter < maxIter
        if custom == false
            m,rad,coords = initCondGen(nBodies,tweet=tweet)
            coordsTmp = deepcopy(coords); mTmp = deepcopy(m); nBodiesTmp = deepcopy(nBodies); rTmp = deepcopy(rad)
            tTmp = 0; collision = false; escape = false
            quitLoop = false
            while quitLoop == false
                coordsTmp,mTmp,rTmp,nBodiesTmp,collisionTmp,collisionIndsTmp,escapeTmp,escapeIndTmp = nBodyStep!(coordsTmp,mTmp,Δt,maxSep*1.5e11,nBodiesTmp,G,rTmp)
                tTmp+=Δt
                if tTmp/yearSec > minYrs || collisionTmp == true || escapeTmp == true
                    quitLoop = true
                end
            end
            if tTmp/yearSec >= minYrs && collision == false && escape == false
                interesting = true
                coordsRecord[1] = deepcopy(coords)
                mStart, radStart, nBodiesStart = deepcopy(m), deepcopy(rad), deepcopy(nBodies)
                println("Found a solution lasting >15 years after $iter iterations")
                v = [coords[3][1],coords[4][1],coords[3][2],coords[4][2],coords[3][3],coords[4][3]]
                pos1 = [coords[1][1],coords[2][1]]./1.5e11; pos2 = [coords[1][2],coords[2][2]]./1.5e11; pos3 = [coords[1][3],coords[2][3]]./1.5e11
                open("initCond.txt","w") do f #save initial conditions to file in folder where script is run
                    write(f,"m1=$(@sprintf("%.1f",(m[1]/2e30))) m2=$(@sprintf("%.1f",(m[2]/2e30))) m3=$(@sprintf("%.1f",(m[3]/2e30))) (solar masses)\nv1x=$(v[1]/1e3) v1y=$(v[2]/1e3) v2x=$(v[3]/1e3) v2y=$(v[4]/1e3) v3x=$(v[5]/1e3) v3y=$(v[6]/1e3) (km/s)\nx1=$(pos1[1]) y1=$(pos1[2]) x2=$(pos2[1]) y2=$(pos2[2]) x3=$(pos3[1]) y3=$(pos3[2]) (AU from center)")
                end
            else
                iter += 1
            end
        else
            interesting = true
            continue #to be implemented, pass in m and init coords
        end
    end

    i = 2; t = Δt; quit = false
    totalKi = sum(m.*(coords[3].^2 .+ coords[4].^2))/2

    function getU(coords,nBodies,m,G)
        totalU = 0; indsList = [i for i=1:nBodies]
        for n = 1:nBodies-1
            totalU += -G*sum([m[n]*mOther for mOther in m[n+1:end]]./[d(coords,n,i) for i=n+1:nBodies])
        end
        return totalU
    end
    totalEi = getU(coords,nBodies,m,G) + totalKi #total initial energy of system
    E = zeros(plotPts)
    E[1] = totalEi
    collision = nothing; collisionInds = nothing; escape = nothing; escapeInd = nothing
    skip = 1; maxSlowdown = 2^(-10); checkT = 1*yearSec; elapsedT = Δt; lastChecked = 0.; skipFac = 1; slowSkip = 1
    while i<length(T)+1 && quit == false
        print("Generating data: Currently at $(@sprintf("%.2f",i/length(T)*maxTime))/$(maxTime)s -- simulation t = $(@sprintf("%.2f",T[i-1]/yearSec)) years\r")
        counter = 0; elapsedT = 0
        while counter < skip && nBodies > 2
            skip = skipFac*slowSkip

            Ki = sum(m.*(coords[3].^2 .+ coords[4].^2))/2
            Ui = getU(coords,nBodies,m,G)
            Ei = Ui + Ki

            coordsTmp,mTmp,rTmp,nBodiesTmp = nBodyStep!(deepcopy(coords),deepcopy(m),Δt,maxSep*1.5e11,deepcopy(nBodies),G,deepcopy(rad)) #try a step at current Δt
            Ef = nBodiesTmp > 2 ? sum(m.*(coordsTmp[3].^2 .+ coordsTmp[4].^2))/2 + getU(coordsTmp,nBodies,m,G) : 0.
            tooBig = abs((Ef-Ei)/Ei) > EframeTol ? true : false #is our timestep too big?
            slowdown = 2^(-1); slowSkip = 1
            while tooBig == true && slowdown > maxSlowdown#if we're going too fast slow down time step to keep total err beneath threshold
                Δt*=slowdown; skip*=2; slowdown*=slowdown; slowSkip*=2
                coordsTmp,mTmp,rTmp,nBodiesTmp,collisionTmp,collisionIndsTmp,escapeTmp,escapeIndTmp = nBodyStep!(deepcopy(coords),deepcopy(m),Δt,maxSep*1.5e11,deepcopy(nBodies),G,deepcopy(rad))
                Ef = nBodiesTmp > 2 ? sum(m.*(coordsTmp[3].^2 .+ coordsTmp[4].^2))/2 + getU(coordsTmp,nBodies,m,G) : 0.
                tooBig = abs((Ef-Ei)/Ei) > EframeTol ? true : false #is our timestep too big?
                if slowdown >= maxSlowdown/2 && nBodiesTmp < 3
                    open("cron_log.txt","a") do f #for cron logging, a flag = append
                        write(f,"$(T[i-1]/yearSec)\n")
                    end
                    open("3BodyStats.txt","a") do f #for stats logging
                        initPos=[coordsRecord[1][1][1],coordsRecord[1][2][1],coordsRecord[1][1][2],coordsRecord[1][2][2],coordsRecord[1][1][3],coordsRecord[1][2][3]]./1.5e11 #AU
                        initV = [coordsRecord[1][3][1],coordsRecord[1][4][1],coordsRecord[1][3][2],coordsRecord[1][4][2],coordsRecord[1][3][3],coordsRecord[1][4][3]]
                        write(f,"$(today()),$(T[end]/(365*24*3600)),$(mStart[1]/2e30),$(mStart[2]/2e30),$(mStart[3]/2e30),$(radStart[1]/7e8),$(radStart[2]/7e8),$(radStart[3]/7e8),$collisionTmp,$(collisionIndsTmp[1]),$(collisionIndsTmp[2]),$(initPos[1]),$(initPos[2]),$(initPos[3]),$(initPos[4]),$(initPos[5]),$(initPos[6]),$(initV[1]/1e3),$(initV[2]/1e3),$(initV[3]/1e3),$(initV[4]/1e3),$(initV[5]/1e3),$(initV[6]/1e3),$i\n")
                    end
                    return coordsRecord[1:i-1], (mStart,m), (radStart,rad), (nBodiesStart,nBodies), T[1:i-1], E[1:i-1], collisionTmp, collisionIndsTmp, escapeTmp, escapeIndTmp, speedRecord[1:i-1]
                end
            end
            if tooBig == false && Δt != ΔtInit && nBodies > 2#try to reset Δt to be default
                ΔtTmp = deepcopy(ΔtInit)
                coordsTmp,mTmp,rTmp,nBodiesTmp = nBodyStep!(deepcopy(coords),deepcopy(m),ΔtTmp,maxSep*1.5e11,deepcopy(nBodies),G,deepcopy(rad))
                Ef = nBodiesTmp > 2 ? sum(m.*(coordsTmp[3].^2 .+ coordsTmp[4].^2))/2 + getU(coordsTmp,nBodies,m,G) : 0.
                tooBig = abs((Ef-Ei)/Ei) > EframeTol ? true : false #is our timestep too big if we go back to original spacing?
                if tooBig == false
                    Δt = deepcopy(ΔtInit)
                    skip /= slowSkip #get rid of slowdown effect on skip
                    slowSkip = 1 #reset
                end
            end
            if nBodies == 3 && nBodiesTmp == 3#try to speed up orbits in 3-body case
                orbiting,x,y = detectOrbiting(d(coordsTmp,1,2),d(coordsTmp,1,3),d(coordsTmp,2,3),m,coordsTmp[1],coordsTmp[2])
                if orbiting != 0 && (T[i-1] + elapsedT) > checkT #check orbit in 3-body case to see if we should speed it up
                    if (T[i-1]+elapsedT-lastChecked)/yearSec >= 1 #don't check again if we recently already checked
                        orbitingTmp = deepcopy(orbiting)
                        coordsTmp = deepcopy(coords); mTmp = deepcopy(m); nBodiesTmp = deepcopy(nBodies); rTmp = deepcopy(rad)
                        tTmp = T[i-1] + elapsedT
                        while orbitingTmp != 0
                            tTmp += Δt
                            coordsTmp,mTmp,rTmp,nBodiesTmp,collisionTmp,collisionIndsTmp,escapeTmp,escapeIndTmp = nBodyStep!(coordsTmp,mTmp,Δt,maxSep*1.5e11,nBodiesTmp,G,rTmp)
                            if collisionTmp == true || escapeTmp == true || (tTmp - T[i-1] + elapsedT)/yearSec > 500
                                orbitingTmp = 0
                            else
                                orbitingTmp,x,y = detectOrbiting(d(coordsTmp,1,2),d(coordsTmp,1,3),d(coordsTmp,2,3),m,coordsTmp[1],coordsTmp[2])
                            end
                        end
                        lastChecked = deepcopy(checkT)
                        checkT = deepcopy(tTmp)

                        ΔtOrbit = (checkT-(T[i-1]+elapsedT))/yearSec #how many years is this orbit aka how many seconds would it take at normal speed
                        if ΔtOrbit > 5 #if it would have taken longer than 5 secs speed it up
                            a = ΔtOrbit/5; rem = a%2
                            skipFac = rem < 1 ? Int(round(a-rem)) : Int(round(a+2-rem)) #round to nearest 2
                            skip *= skipFac
                        else
                            skip = skip > 1 ? skip/skipFac : skip
                            skipFac = 1
                        end
                    end
                elseif orbiting == 0 && (T[i-1]+elapsedT) > checkT && (T[i-1] + elapsedT) > (lastChecked + 0.5*yearSec)
                    lastChecked = T[i-1]+elapsedT
                    checkT = lastChecked+yearSec*0.5
                    skip = skip > 1 ? skip/skipFac : skip
                    skipFac = 1
                end
            end
            counter+=1; elapsedT += Δt
            coords,m,rad,nBodies,collision,collisionInds,escape,escapeInd = nBodyStep!(coords,m,Δt,maxSep*1.5e11,nBodies,G,rad) #do the update with our Δt
        end
        if nBodies < 3 || escape == true
            quit = true
            coordsRecord = coordsRecord[1:i-1]; T = T[1:i-1]; E = E[1:i-1]; speedRecord = speedRecord[1:i-1] #truncate
        else
            coordsRecord[i] = deepcopy(coords); T[i] = T[i-1] + elapsedT; speedRecord[i] = skip/slowSkip; E[i] = sum(m.*(coords[3].^2 .+ coords[4].^2))/2 + getU(coords,nBodies,m,G)
            i+=1
        end
    end
    collisionInds = collision == false ? [0,0] : collisionInds
    coords = coordsRecord[end]
    finalE = sum(mStart.*(coords[3].^2 .+ coords[4].^2))/2 + getU(coords,nBodiesStart,mStart,G)
    err = (finalE-totalEi)/totalEi
    open("cron_log.txt","a") do f #for cron logging, a flag = append
        write(f,"$(T[end]/yearSec)\n")
    end
    open("3BodyStats.txt","a") do f #for stats logging
        initPos=[coordsRecord[1][1][1],coordsRecord[1][2][1],coordsRecord[1][1][2],coordsRecord[1][2][2],coordsRecord[1][1][3],coordsRecord[1][2][3]]./1.5e11 #AU
        initV = [coordsRecord[1][3][1],coordsRecord[1][4][1],coordsRecord[1][3][2],coordsRecord[1][4][2],coordsRecord[1][3][3],coordsRecord[1][4][3]]
        write(f,"$(today()),$(T[end]/(365*24*3600)),$(mStart[1]/2e30),$(mStart[2]/2e30),$(mStart[3]/2e30),$(radStart[1]/7e8),$(radStart[2]/7e8),$(radStart[3]/7e8),$collision,$(collisionInds[1]),$(collisionInds[2]),$(initPos[1]),$(initPos[2]),$(initPos[3]),$(initPos[4]),$(initPos[5]),$(initPos[6]),$(initV[1]/1e3),$(initV[2]/1e3),$(initV[3]/1e3),$(initV[4]/1e3),$(initV[5]/1e3),$(initV[6]/1e3),$i\n")
    end
    return coordsRecord, (mStart,m), (radStart,rad), (nBodiesStart,nBodies), T, E, collision, collisionInds, escape, escapeInd, speedRecord
end



######################################### PLOTTING SECTION ############################################

function convertData(coordsRecord,T)
    #coordsRecord has shape [x(nBodies),y(nBodies),vx(nBodies),vy(nBodies) for t in T]
    #but old version of code used format [x1(t),y1(t),x2(t),y2(t),x3(t),y3(t)] and plotting still uses this
    #so we need to convert; only use for 3-bodies
    x1 = zeros(length(T)); y1 = zeros(length(T)); x2 = zeros(length(T)); y2 = zeros(length(T)); x3 = zeros(length(T)); y3 = zeros(length(T))
    for t=1:length(T)
        coords = coordsRecord[t]
        x1[t] = coords[1][1]
        y1[t] = coords[2][1]
        x2[t] = coords[1][2]
        y2[t] = coords[2][2]
        x3[t] = coords[1][3]
        y3[t] = coords[2][3]
    end
    return [x1,y1,x2,y2,x3,y3]
end
    #[plotData[1][i],plotData[2][i],plotData[3][i],plotData[4][i],plotData[5][i],plotData[6][i]]
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
                    println(signdx)
                    println(signdy)
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

function main(tweet=nothing) #pulls everything together, only works for 3 body case (for now...)
    println("sit tight -- finding an interesting solution")
    coordsRecord, m, rad, nBodies, t, err, collisionBool, collisionInds, escape, escapeInd, speedRecord = getData(3,tweet=tweet) #find an interesting solution at least 15 years
    m = m[1]; rad = rad[1]; nBodies = nBodies[1] #each of these vars before this are tuples going like (startVal, endVal) and we want the starting ones
    plotData = convertData(coordsRecord,t)

    if collisionBool == true
        println("\ncollision! inds = $collisionInds")
    elseif escape == true
        println("\nbody $escapeInd escaped!")
    else
        println("\nno collision")
    end

    c=[:DodgerBlue,:Gold,:Tomato] #most massive to least massive, also roughly corresponds to temp
    colors=getColors(m,c)
    #adding fake stars
    x = [coordsRecord[i][1] for i=1:length(coordsRecord)]; y = [coordsRecord[i][2] for i=1:length(coordsRecord)]
    minBox = 0.; maxBox = 0.
    for coords in coordsRecord
        if maximum([maximum(coords[1]),maximum(coords[2])])/1.5e11 > maxBox
            maxBox = maximum([maximum(coords[1]),maximum(coords[2])])/1.5e11
        end
        if minimum([minimum(coords[1]),minimum(coords[2])])/1.5e11 < minBox
            minBox = minimum([minimum(coords[1]),minimum(coords[2])])/1.5e11
        end
    end
    maxBox = round(Int,maxBox); minBox = round(Int,minBox)
    boxSize = (maxBox-minBox)
    numStars=round(Int,(2500/400^2)*(boxSize+100)^2)
    starsX=zeros(numStars)
    starsY=zeros(numStars)
    for i=1:numStars
        num=rand(minBox-50:maxBox+50,2) #we need some extra padding for frame
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
    stop=length(t)-333
    listInd=0
    limList=[]
    ratio=1
    offsetX = [0.,0.]; offsetY = [0.,0.]
    orbitOld = 0
    center = [0.,0.]; vel = [0.,0.]
    ΔCx = 0.;ΔCy = 0.;ΔL = 0.;ΔR = 0.;ΔU = 0.;ΔD = 0.
    println("energy loss = $((err[end]-err[1])/err[1]*100) %") #should always be less than 0.001%
    lasti = 0
    for i=1:333:stop #this makes animation scale ~1 sec/year with other conditions
        skipPts = 33
        if i>333*30*4
            if maximum(speedRecord[i-333*30*4:i]) > 1 && speedRecord[i] == 1 #were we orbiting at any point in the last 4 seconds?
                if maximum(speedRecord[i-333*30*4:i]) > 6
                    skipPts = 1
                else
                    skipPts = 10
                end
            end
        end
        GR.inline("png") #added to eneable cron/jobber compatibility, also this makes frames generate WAY faster? Prior to adding this when run from cron/jobber frames would stop generating at 408 for some reason.
        gr(legendfontcolor = plot_color(:white)) #legendfontcolor=:white plot arg broken right now (at least in this backend)
        print("$(@sprintf("%.2f",i/length(t)*100)) % complete\r") #output percent tracker
        pos=[plotData[1][i],plotData[2][i],plotData[3][i],plotData[4][i],plotData[5][i],plotData[6][i]] #current pos
        future = i+500 < stop ? i+500 : i #make sure we don't go past end of data
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
        p=plot(plotData[1][1:skipPts:i]./1.5e11,plotData[2][1:skipPts:i]./1.5e11,label="",linewidth=2,linecolor=colors[1],linealpha=max.((1:skipPts:i) .+ 10000 .- i,2500)/10000) #plot orbits up to i
        p=plot!(plotData[3][1:skipPts:i]./1.5e11,plotData[4][1:skipPts:i]./1.5e11,label="",linewidth=2,linecolor=colors[2],linealpha=max.((1:skipPts:i) .+ 10000 .- i,2500)/10000) #linealpha argument causes lines to decay
        p=plot!(plotData[5][1:skipPts:i]./1.5e11,plotData[6][1:skipPts:i]./1.5e11,label="",linewidth=2,linecolor=colors[3],linealpha=max.((1:skipPts:i) .+ 10000 .- i,2500)/10000) #example: alpha=max.((1:i) .+ 100 .- i,0) causes only last 100 to be visible
        p=scatter!(starsX,starsY,markercolor=:white,markersize=:1,label="") #fake background stars
        star1=makeCircleVals(rad[1],[plotData[1][i],plotData[2][i]]) #generate circles with appropriate sizes for each star
        star2=makeCircleVals(rad[2],[plotData[3][i],plotData[4][i]]) #at current positions
        star3=makeCircleVals(rad[3],[plotData[5][i],plotData[6][i]])
        p=plot!(star1[1]./1.5e11,star1[2]./1.5e11,label="$(@sprintf("%.1f", m[1]./2e30))",color=colors[1],fill=true) #plot star circles with labels
        p=plot!(star2[1]./1.5e11,star2[2]./1.5e11,label="$(@sprintf("%.1f", m[2]./2e30))",color=colors[2],fill=true)
        p=plot!(star3[1]./1.5e11,star3[2]./1.5e11,label="$(@sprintf("%.1f", m[3]./2e30))",color=colors[3],fill=true)
        p=plot!(background_color=:black,background_color_legend=:transparent,foreground_color_legend=:transparent,fontfamily=:Courier,
            background_color_outside=:white,aspect_ratio=:equal,legendtitlefontcolor=:white) #formatting for plot frame
        title = t[i]/365/24/3600 < 100 ? "Random Three-Body Problem\nt:      years after start" : "Random Three-Body Problem\nt:       years after start"
        p=plot!(xlabel="x: AU",ylabel="y: AU",title=title,
            legend=:best,xaxis=("x: AU",(limx[1],limx[2]),font(9,"Courier")),yaxis=("y: AU",(limy[1],limy[2]),font(9,"Courier")),tickfontcolor=:white,
            grid=false,titlefont=font(14,"Courier"),size=(720,721),legendfontsize=8,legendtitle="Mass (in solar masses)",legendtitlefontsize=8) #add in axes/title/legend with formatting

        tX,tY=relative(p[1],0.295,1.041)#static coords for time relative to parent
        p = annotate!(tX,tY,Plots.text((@sprintf("%0.2f",t[i]/365/24/3600)),"Courier",14,"black"))
        sX,sY = relative(p[1],1/8,19/20)
        if speedRecord[i] != 1.
            p = annotate!(sX,sY,Plots.text(("x$(Int(speedRecord[i])) speed"),"Courier",10,"orange","left"))
        end
        png(p,@sprintf("tmpPlots/frame_%06d.png",frameNum))
        frameNum+=1
        closeall() #close plots
        lasti = i
    end

    if collisionBool==true #this condition makes ~2 seconds of slo-mo right before the collision
        sloInd = length(t) - lasti < 600 ? length(t) - lasti : 600
        println("making collision cam")
        for i=1:10:sloInd
            skipPts = 33
            if speedRecord[end-(sloInd-i)-333] > 2
                if speedRecord[end-(sloInd-i)-333] > 10
                    skipPts = 1
                else
                    skipPts = 10
                end
            end
            GR.inline("png") #added to eneable cron/jobber compatibility, also this makes frames generate WAY faster? Prior to adding this when run from cron/jobber frames would stop generating at 408 for some reason.
            gr(legendfontcolor = plot_color(:white)) #legendfontcolor=:white plot arg broken right now (at least in this backend)
            print("$(@sprintf("%.2f",i/sloInd*100)) % complete\r") #output percent tracker
            pos=[plotData[1][end-(sloInd-i)],plotData[2][end-(sloInd-i)],plotData[3][end-(sloInd-i)],plotData[4][end-(sloInd-i)],plotData[5][end-(sloInd-i)],plotData[6][end-(sloInd-i)]] #current pos
            posFuture=pos #don't need future position at end
            limx,limy,center,orbitOld,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD=computeLimits(pos./1.5e11,posFuture./1.5e11,15,m,orbitOld,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD) #convert to AU, 10 AU padding
            p=plot(plotData[1][1:skipPts:end-(sloInd-i)]./1.5e11,plotData[2][1:skipPts:end-(sloInd-i)]./1.5e11,label="",linecolor=colors[1],linewidth=2,linealpha=max.((1:skipPts:(i+length(t)-sloInd)) .+ 10000 .- (i+length(t)-sloInd),2500)/10000) #plot orbits up to i
            p=plot!(plotData[3][1:skipPts:end-(sloInd-i)]./1.5e11,plotData[4][1:skipPts:end-(sloInd-i)]./1.5e11,label="",linecolor=colors[2],linewidth=2,linealpha=max.((1:skipPts:(i+length(t)-sloInd)) .+ 10000 .- (i+length(t)-sloInd),2500)/10000) #linealpha argument causes lines to decay
            p=plot!(plotData[5][1:skipPts:end-(sloInd-i)]./1.5e11,plotData[6][1:skipPts:end-(sloInd-i)]./1.5e11,label="",linecolor=colors[3],linewidth=2,linealpha=max.((1:skipPts:(i+length(t)-sloInd)) .+ 10000 .- (i+length(t)-sloInd),2500)/10000) #example: alpha=max.((1:i) .+ 100 .- i,0) causes only last 100 to be visible
            p=scatter!(starsX,starsY,markercolor=:white,markersize=:1,label="") #fake background stars
            star1=makeCircleVals(rad[1],[plotData[1][end-(sloInd-i)],plotData[2][end-(sloInd-i)]]) #generate circles with appropriate sizes for each star
            star2=makeCircleVals(rad[2],[plotData[3][end-(sloInd-i)],plotData[4][end-(sloInd-i)]]) #at current positions
            star3=makeCircleVals(rad[3],[plotData[5][end-(sloInd-i)],plotData[6][end-(sloInd-i)]])
            p=plot!(star1[1]./1.5e11,star1[2]./1.5e11,label="$(@sprintf("%.1f", m[1]./2e30))",color=colors[1],fill=true) #plot star circles with labels
            p=plot!(star2[1]./1.5e11,star2[2]./1.5e11,label="$(@sprintf("%.1f", m[2]./2e30))",color=colors[2],fill=true)
            p=plot!(star3[1]./1.5e11,star3[2]./1.5e11,label="$(@sprintf("%.1f", m[3]./2e30))",color=colors[3],fill=true)
            p=plot!(background_color=:black,background_color_legend=:transparent,foreground_color_legend=:transparent,
                background_color_outside=:white,aspect_ratio=:equal,legendtitlefontcolor=:white,fontfamily=:Courier) #formatting for plot frame
            p=plot!(xlabel="x: AU",ylabel="y: AU",title="Random Three-Body Problem\nt: $(@sprintf("%0.2f",t[end-(sloInd-i)]/365/24/3600)) years after start",
                legend=:best,xaxis=("x: AU",(limx[1],limx[2]),font(9,"Courier")),yaxis=("y: AU",(limy[1],limy[2]),font(9,"Courier")),
                grid=false,titlefont=font(14,"Courier"),size=(720,721),legendfontsize=8,legendtitle="Mass (in solar masses)",legendtitlefontsize=8) #add in axes/title/legend with formatting
            #collision cam zoom in
            i1,i2=collisionInds #these are the ones that are colliding, we use them to set the frame limits
            X=[plotData[1][end-(sloInd-i)],plotData[3][end-(sloInd-i)],plotData[5][end-(sloInd-i)]]./1.5e11; Y=[plotData[2][end-(sloInd-i)],plotData[4][end-(sloInd-i)],plotData[6][end-(sloInd-i)]]./1.5e11
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
            p=plot!(p[2],plotData[1][1:10:end-(sloInd-i)]./1.5e11,plotData[2][1:10:end-(sloInd-i)]./1.5e11,label="",linecolor=colors[1],linewidth=2,linealpha=max.((1:10:(i+length(t)-sloInd)) .+ 10000 .- (i+length(t)-sloInd),2500)/10000)
            p=plot!(p[2],plotData[3][1:10:end-(sloInd-i)]./1.5e11,plotData[4][1:10:end-(sloInd-i)]./1.5e11,label="",linecolor=colors[2],linewidth=2,linealpha=max.((1:10:(i+length(t)-sloInd)) .+ 10000 .- (i+length(t)-sloInd),2500)/10000)
            p=plot!(p[2],plotData[5][1:10:end-(sloInd-i)]./1.5e11,plotData[6][1:10:end-(sloInd-i)]./1.5e11,label="",linecolor=colors[3],linewidth=2,linealpha=max.((1:10:(i+length(t)-sloInd)) .+ 10000 .- (i+length(t)-sloInd),2500)/10000)
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
        for i=1:30 #make 1 s freeze frame ending
            GR.inline("png") #added to eneable cron/jobber compatibility, also this makes frames generate WAY faster? Prior to adding this when run from cron/jobber frames would stop generating at 408 for some reason.
            gr(legendfontcolor = plot_color(:white)) #legendfontcolor=:white plot arg broken right now (at least in this backend)
            print("$(@sprintf("%.2f",i/30*100)) % complete\r") #output percent tracker
            pos=[plotData[1][end],plotData[2][end],plotData[3][end],plotData[4][end],plotData[5][end],plotData[6][end]] #current pos
            posFuture=pos #don't need future position at end
            limx,limy,center,orbitOld,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD=computeLimits(pos./1.5e11,posFuture./1.5e11,15,m,orbitOld,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD) #convert to AU, 10 AU padding
            p=plot(plotData[1][1:10:end]./1.5e11,plotData[2][1:10:end]./1.5e11,label="",linecolor=colors[1],linewidth=2,linealpha=max.((1:10:(length(t))) .+ 10000 .- (length(t)),2500)/10000) #plot orbits up to i
            p=plot!(plotData[3][1:10:end]./1.5e11,plotData[4][1:10:end]./1.5e11,label="",linecolor=colors[2],linewidth=2,linealpha=max.((1:10:(length(t))) .+ 10000 .- (length(t)),2500)/10000) #linealpha argument causes lines to decay
            p=plot!(plotData[5][1:10:end]./1.5e11,plotData[6][1:10:end]./1.5e11,label="",linecolor=colors[3],linewidth=2,linealpha=max.((1:10:(length(t))) .+ 10000 .- (length(t)),2500)/10000) #example: alpha=max.((1:i) .+ 100 .- i,0) causes only last 100 to be visible
            p=scatter!(starsX,starsY,markercolor=:white,markersize=:1,label="") #fake background stars
            star1=makeCircleVals(rad[1],[plotData[1][end],plotData[2][end]]) #generate circles with appropriate sizes for each star
            star2=makeCircleVals(rad[2],[plotData[3][end],plotData[4][end]]) #at current positions
            star3=makeCircleVals(rad[3],[plotData[5][end],plotData[6][end]])
            p=plot!(star1[1]./1.5e11,star1[2]./1.5e11,label="$(@sprintf("%.1f", m[1]./2e30))",color=colors[1],fill=true) #plot star circles with labels
            p=plot!(star2[1]./1.5e11,star2[2]./1.5e11,label="$(@sprintf("%.1f", m[2]./2e30))",color=colors[2],fill=true)
            p=plot!(star3[1]./1.5e11,star3[2]./1.5e11,label="$(@sprintf("%.1f", m[3]./2e30))",color=colors[3],fill=true)
            p=plot!(background_color=:black,background_color_legend=:transparent,foreground_color_legend=:transparent,
                background_color_outside=:white,aspect_ratio=:equal,legendtitlefontcolor=:white,fontfamily=:Courier) #formatting for plot frame
            p=plot!(xlabel="x: AU",ylabel="y: AU",title="Random Three-Body Problem\nt: $(@sprintf("%0.2f",t[end]/365/24/3600)) years after start",
                legend=:best,xaxis=("x: AU",(limx[1],limx[2]),font(9,"Courier")),yaxis=("y: AU",(limy[1],limy[2]),font(9,"Courier")),
                grid=false,titlefont=font(14,"Courier"),size=(720,721),legendfontsize=8,legendtitle="Mass (in solar masses)",legendtitlefontsize=8) #add in axes/title/legend with formatting
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
    elseif escape == true
        println("making freeze frame ending")
        for i = 1:45
            GR.inline("png") #added to eneable cron/jobber compatibility, also this makes frames generate WAY faster? Prior to adding this when run from cron/jobber frames would stop generating at 408 for some reason.
            gr(legendfontcolor = plot_color(:white)) #legendfontcolor=:white plot arg broken right now (at least in this backend)
            print("$(@sprintf("%.2f",i/45*100)) % complete\r") #output percent tracker
            pos=[plotData[1][end],plotData[2][end],plotData[3][end],plotData[4][end],plotData[5][end],plotData[6][end]] #current pos
            posFuture=pos #don't need future position at end
            limx,limy,center,orbitOld,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD=computeLimits(pos./1.5e11,posFuture./1.5e11,15,m,orbitOld,ΔCx,ΔCy,ΔL,ΔR,ΔU,ΔD) #convert to AU, 10 AU padding
            p=plot(plotData[1][1:10:end]./1.5e11,plotData[2][1:10:end]./1.5e11,label="",linecolor=colors[1],linewidth=2,linealpha=max.((1:10:(length(t))) .+ 10000 .- (length(t)),2500)/10000) #plot orbits up to i
            p=plot!(plotData[3][1:10:end]./1.5e11,plotData[4][1:10:end]./1.5e11,label="",linecolor=colors[2],linewidth=2,linealpha=max.((1:10:(length(t))) .+ 10000 .- (length(t)),2500)/10000) #linealpha argument causes lines to decay
            p=plot!(plotData[5][1:10:end]./1.5e11,plotData[6][1:10:end]./1.5e11,label="",linecolor=colors[3],linewidth=2,linealpha=max.((1:10:(length(t))) .+ 10000 .- (length(t)),2500)/10000) #example: alpha=max.((1:i) .+ 100 .- i,0) causes only last 100 to be visible
            p=scatter!(starsX,starsY,markercolor=:white,markersize=:1,label="") #fake background stars
            star1=makeCircleVals(rad[1],[plotData[1][end],plotData[2][end]]) #generate circles with appropriate sizes for each star
            star2=makeCircleVals(rad[2],[plotData[3][end],plotData[4][end]]) #at current positions
            star3=makeCircleVals(rad[3],[plotData[5][end],plotData[6][end]])
            p=plot!(star1[1]./1.5e11,star1[2]./1.5e11,label="$(@sprintf("%.1f", m[1]./2e30))",color=colors[1],fill=true) #plot star circles with labels
            p=plot!(star2[1]./1.5e11,star2[2]./1.5e11,label="$(@sprintf("%.1f", m[2]./2e30))",color=colors[2],fill=true)
            p=plot!(star3[1]./1.5e11,star3[2]./1.5e11,label="$(@sprintf("%.1f", m[3]./2e30))",color=colors[3],fill=true)
            p=plot!(background_color=:black,background_color_legend=:transparent,foreground_color_legend=:transparent,
                background_color_outside=:white,aspect_ratio=:equal,legendtitlefontcolor=:white,fontfamily=:Courier) #formatting for plot frame
            p=plot!(xlabel="x: AU",ylabel="y: AU",title="Random Three-Body Problem\nt: $(@sprintf("%0.2f",t[end]/365/24/3600)) years after start",
                legend=:best,xaxis=("x: AU",(limx[1],limx[2]),font(9,"Courier")),yaxis=("y: AU",(limy[1],limy[2]),font(9,"Courier")),
                grid=false,titlefont=font(14,"Courier"),size=(720,721),legendfontsize=8,legendtitle="Mass (in solar masses)",legendtitlefontsize=8) #add in axes/title/legend with formatting

            sX,sY = relative(p[1],1/6,19/20)
            n = escapeInd; x = coordsRecord[end][1]; y = coordsRecord[end][2]; vx = coordsRecord[end][3]; vy = coordsRecord[end][4]
            CMX = sum(m[1:end .!= n].*x[1:end .!= n])/sum(m[1:end .!= n])
            CMY = sum(m[1:end .!= n].*y[1:end .!= n])/sum(m[1:end .!= n])
            CMDist = sqrt((x[n]-CMX)^2+(y[n]-CMY)^2)
            V = sqrt(vx[n]^2+vy[n]^2)
            vEsc = sqrt(2*6.67e-11*sum(m[1:end .!= n])/CMDist)
            p = annotate!(sX,sY,Plots.text(("Body $escapeInd escaped\nwith v = $(@sprintf("%.2f",V/vEsc))x\nescape velocity"),"Courier",10,colors[n],"left"))
            png(p,@sprintf("tmpPlots/frame_%06d.png",frameNum))
            frameNum+=1
            closeall() #close plots
        end
    end
end

function makeAnim(clean=true; tweet=nothing)
    run(`ffmpeg -framerate 30 -i "tmpPlots/frame_%06d.png" -c:v libx264 -preset slow -coder 1 -movflags +faststart -g 15 -crf 18 -pix_fmt yuv420p -profile:v high -y -bf 2 -vf "scale=720:720,setdar=1/1" "threeBody.mp4"`)
    if clean==true
        println("cleaning up png files")
        foreach(rm,[string("tmpPlots/",x) for x in filter(endswith(".png"),readdir("tmpPlots"))])
    end
    if tweet != nothing
        musicList = ["Music: Adagio for Strings – Barber","Music: The Blue Danube Waltz – Strauss","Music: Moonlight Sonata (1st Mvmt) – Beethoven","Music: Clair de Lune – Debussy",
        "Music: Gymnopédie No. 1 – Satie","Music: Symphony No. 5 (1st Mvmt) – Beethoven","Music: First Step (Interstellar) – Zimmer","Music: Time (Inception) – Zimmer","Music: I Need a Ride (The Expanse) – Shorter",
        "Music: Prelude in E Minor – Chopin","Music: Nocturne in C-Sharp Minor (Posthumous) – Chopin","Music: Battlestar Sonatica (BSG) – McCreary","Music: Rhapsody in Blue – Gershwin",
        "Music: Passacaglia (BSG) – McCreary","Music: Prelude in G Minor – Rachmaninoff","Music: Prelude in C-Sharp Minor – Rachmaninoff","Music: The Shape of Things To Come (BSG) – McCreary",
        "Music: Prelude in C Major – Bach","Music: Liebestraum – Liszt","Music: Where is My Mind? – Pixies/Cyrin","Music: Lost (The Expanse) – Shorter","Music: What Did You Do (The Expanse) – Shorter",
        "Music: Waltz of the Flowers – Tchaikovsky","Music: Memories of Green – Vangelis","Music: Memories of Green – Vangelis","Music: Dune (2021) Medley – Zimmer"]
        s = readlines("TweetJSON.txt")
        j = JSON.parse(s[1])
        bodySplit = split(j["data"]["text"],"\n")
        music = split(bodySplit[end], " ")
        str = ""
        for i = 1:length(music)-1
            str *= i<length(music)-1 ? string(music[i]," ") : music[i]
        end
        num = 0
        for i = 1:length(musicList)
            if musicList[i] == str
                num = i
            end
        end
        musicFile = "music/music_choice_$num.m4a"
        videoFile = "threeBody.mp4"
        run(`ffmpeg -i $videoFile -i $musicFile -c:a aac -shortest -preset slow -y 3Body_fps30_wMusicAAC.mp4`)
    end
end

main()
#makeAnim() #commented out because bot uses shell script to compile frames with music
