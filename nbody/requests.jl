#!/usr/bin/env julia
using Plots, Random, Printf, Plots.PlotMeasures
include("IMF.jl") #new way to make random masses more "realistic"?
function initCondGen(nBodies,m;vRange=[-7e3,7e3],posRange=[-35,35]) #get random initial conditions for mass/radius, position, and velocity, option for user to specify acceptable vRange and posRange
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
    v=[]
    for n=1:nBodies
        push!(v,rand(minV:maxV,2)) #random x & y velocity between minV:maxV, km/s
    end
    r=[] #r is master vector containing both position and velocity info for all bodies that we will need later
    for n=1:nBodies
        push!(r,pos[n]) #position is first half of r
    end
    for n=1:nBodies
        push!(r,v[n]) #v is second half of r
    end
    #NOTE: if you want to specify the initial positions and/or velocities uncomment and fill in the sample lines below
    #technically if you want to save a bit of computation time you should also comment out lines 34 & 35
    #pos=[[pos1X,pos1Y],[pos2X,pos2Y],[pos3X,pos3Y],.....,[posNX,posNY]].*1.5e11 #fill this in if you want to specify the positions, units of AU from center
    #v=[[v1X,v1Y],[v1X,v1Y],[v3X,v3Y],......,[vNX,vNY]].*1e3 #fill this in to specify initial velocities, units of km/s
    #v=[[6.639,1.804],[-1.807,-0.998],[5.966,-4.904]].*1e3
    #pos=[[-4,-34],[-4,-3],[-33,32]].*1.5e11
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
    return [r, rad, m]
end

function dR(r,m,nBodies) #function we will use RK4 on to approximate solution
    G=6.67408313131313e-11# Nm^2/kg^2
    C=m.*G #Nm^2/kg
    function getDist(pos1,pos2) #find separation between two bodies
        x1,y1=pos1[1],pos1[2]
        x2,y2=pos2[1],pos2[2]
        dist=sqrt((x1-x2)^2+(y1-y2)^2)
        return dist
    end
    function getDv(C,n,r,nBodies) #find acceleration for a given body from Newton's law of gravitation
        pos=r[1:nBodies]
        dVx=0
        dVy=0
        for i=1:nBodies
            if i!=n #only do this if other body is NOT self
                dist=getDist(pos[n],pos[i])
                c=C[i]
                dVx-=c*(pos[n][1]-pos[i][1])/dist^3 #m/s after *dt
                dVy-=c*(pos[n][2]-pos[i][2])/dist^3
            end
        end
        return [dVx,dVy]
    end

    rUpdate=copy(r) #otherwise we modify r in place, in Julia array variables are just pointers
    dr=r[(nBodies+1):nBodies*2] #old v*dt = dr
    dv=[]
    for n=1:nBodies
        dVn=getDv(C,n,r,nBodies) #get the dv info for all bodies
        push!(dv,dVn)
    end
    rUpdate[1:nBodies]=dr[1:nBodies] #update positions
    rUpdate[(nBodies+1):nBodies*2]=dv[1:nBodies] #update velocities
    return rUpdate #r updated after timestep
end

function checkSep(xList,yList,nBodies,i,m,r,rad,names,colors,maxSep) #this function detects collisions and performs bookkeeping
                sepList=[]
                for n1=1:nBodies
                    for n2=(n1+1):nBodies
                        x1,y1=xList[n1][i],yList[n1][i] #get position info from data
                        x2,y2=xList[n2][i],yList[n2][i]
                        sep=sqrt((x1-x2)^2+(y1-y2)^2)
                        push!(sepList,sep) #get all the separations in a list
                        minSep=rad[n1]+rad[n2] #no touching!
                        split1,split2=split(names[n1]),split(names[n2])
                        if split1[end]=="hole" || split2[end]=="hole"
                            minSep*=2 #black holes are v smol so need to make the "hit box" bigger to prevent erroneous flying
                        elseif split1[end]=="hole" && split2[end]=="hole"
                            minSep*=100000 #two black holes are V SMOL
                        end
                        if sep<minSep
                            println("collision between indices $n1 and $n2")
                            #println("names before modification: $names")
                            #println("masses before modification: $(m./2e30)")
                            sharedX=(x1+x2)/2 #collision detected, so assign new coordinate values for resulting "black hole"
                            sharedY=(y1+y2)/2
                            p1x,p1y=m[n1]*r[n1+nBodies][1],m[n1]*r[n1+nBodies][2] #get initial momenta from each body
                            p2x,p2y=m[n2]*r[n2+nBodies][1],m[n2]*r[n2+nBodies][2]
                            pTotx,pToty=p1x+p2x,p1y+p2y #calculate total momentum before collision in each direction
                            newMass=m[n1]+m[n2] #calculate new mass
                            sharedVfX=pTotx/(newMass) #get new velocity by dividing momentum in each direction by total mass
                            sharedVfY=pToty/(newMass) #idealized perfectly inelastic collision
                            r[n1][1]=sharedX #replace coordinates of one of the old bodies with new shared coords
                            r[n1][2]=sharedY
                            r[n1+nBodies][1]=sharedVfX #ditto for velocity
                            r[n1+nBodies][2]=sharedVfY
                            r[n2]=true #mark for removal
                            r[n2+nBodies]=true
                            filter!(x->x!=true,r) #filter and remove n2 entries, because now there's only 1 body from this pair
                            if split1[end]=="hole" #this is bookkeeping to make sure labels stay right on plot
                                names[n1]=names[n1][1:(end-11)] #remove "black hole" from end of label to avoid things like "1 & 2 black hole & 3 black hole"
                            elseif split2[end]=="hole"
                                names[n2]=names[n2][1:(end-11)]
                            end
                            newName=string("$(@sprintf("%.1f",(newMass/2e30))) black hole") #update name to reflect collision
                            names[n1]=newName #update n1 index since this is the one we "keep"
                            deleteat!(names,n2) #get rid of n2 since we don't need it anymore
                            deleteat!(colors,n2) #ditto for n2 color
                            m[n1]=newMass #update mass to reflect merger
                            deleteat!(m,n2) #delete the other
                            newRad=2*(6.6743015e-11)*newMass/(9e16) #schwarzschild radius -- might change because it's tiny on plots but whatever
                            rad[n1]=newRad #update radii list to reflect merger
                            deleteat!(rad,n2) #get rid of the other one
                            #println("names after modification: $names")
                            #println("masses after modification: $(m./2e30)")
                            return true,r,nBodies-1,names,colors,m,rad #now we have 1 less body so return updated info!
                        end
                    end
                end
                if length(sepList)>1
                    if minimum(sepList)>maxSep*1.5e11
                        return true,r,nBodies,names,colors,m,rad #stop if everybody flew away from each other
                    end
                end
                return false,r,nBodies,names,colors,m,rad #if nothing interesting happend just return everything unmodified
            end

function genNBodyStep(nBodies, physInfo, names, colors, stopCond=[10,100],dt=0.033) #default stop conditions of 10 yrs and 100 AU sep
    tStop=stopCond[1]*365*24*3600 #convert to SI s
    sepStop=stopCond[2]*1.5e11 #convert to SI m
    stop=false
    numSteps=Int(ceil(stopCond[1]/dt))
    t=range(0,stop=tStop,length=(numSteps+1)) #+1 because I don't want 0 to count
    stepSize=dt*365*24*3600 #convert to SI s
    xList=[]
    yList=[]
    for n=1:nBodies
        push!(xList,zeros(length(t))) #technically everything with push! is a little slower than pre-allocating but I'm very lazy and this doesn't need to be done that often so whatever
        push!(yList,zeros(length(t)))
    end
    r,rad,m=copy(physInfo[1]),copy(physInfo[2]),copy(physInfo[3]) #need copy because otherwise they're just pointers
    colors=copy(colors) #same reasoning as above
    names=copy(names) # ^^^
    i=1
    currentT=t[i] #do it this way other than +=stepSize because this mitigates rounding error
    #implement RK4 to model solutions to differential equations
    while stop==false
        if currentT>=tStop #in case of rounding error or something
            stop=true
        elseif i>(numSteps+1) #inf loop failsafe
            stop=true
            println("error: shouldn't have gotten here")
        else
            for n=1:nBodies
                xList[n][i]=r[n][1]
                yList[n][i]=r[n][2]
            end
            k1=stepSize.*dR(r,m,nBodies)
            k2=stepSize.*dR(r.+0.5.*k1,m,nBodies)
            k3=stepSize.*dR(r.+0.5.*k2,m,nBodies)
            k4=stepSize.*dR(r.+k3,m,nBodies)
            r.+=(k1.+2.0.*k2.+2.0.*k3.+k4)./6 #basically dt*(dr/dt,dv/dt) gives us updated r vector
            #check separation after each dt step
            stop,r,nBodies,names,colors,m,rad=checkSep(xList,yList,nBodies,i,m,r,rad,names,colors,sepStop)
            if stop==true
                t=range(0,stop=currentT,length=i) #t should match pos vectors
                for n=1:(nBodies+1)
                    xList[n]=xList[n][1:i] #cut off trailing zeros
                    yList[n]=yList[n][1:i]
                end
            else
                i+=1
                currentT=t[i] #on to the next one!
            end
        end
    end
    return ([xList, yList, t], [r, rad, m], nBodies, names, colors, currentT/365/24/3600)
end

function genNBody(nBodies, m, names, colors; stopCond=[10,100],dt=0.033,vRange=[-7e3,7e3],posRange=[-35,35]) #this function makes all the data for an entire nBody run
    globalT=0
    stopT=stopCond[1] #yrs
    numTrials=0
    plotList=[]
    tOffsets=[0.0] #first offest should be zero years
    colorsList=[colors] #first set of colors is just original colors
    physInfoList=[]
    namesList=[]
    nBodiesList=[nBodies]
    nBodiesGlobal=nBodies
    while globalT<stopT && nBodies>1 #go until we reach given time or there's one giant black hole
        numTrials+=1
        function firstStep(nBodies0,m0,names0,colors0,stopT,globalT,stopCond2,dt) #try to find a first step that goes for a reasonable amount of time without immediate collisions
            accept=false
            iter=1
            mLocal=copy(m0)
            iMax=1999
            global labelBool
            if labelBool==1
                iMax=0 #we set the mass in init cond
            end
            while accept==false
                if iter==1
                    mInit=m0
                else
                    mInit=rand(1:1500,nBodies0)./10 #n random masses between 0.1 and 150 solar masses
                    #mInit=getMass(nBodies0) #IMF way
                end
                physInfo0=initCondGen(nBodies0,mInit,vRange=vRange,posRange=posRange) #get initial conditions
                rad,m=physInfo0[2],physInfo0[3] #r is the first thing but we don't need it here
                newNames=["$(mInit[i])" for i=1:length(mInit)]
                plotInfo,newPhysInfo,nBodies,names,colors,t=genNBodyStep(nBodies0,physInfo0,newNames,colors0,[stopT-globalT,stopCond2],dt) #generate one step -- ie until there is a collision
                #println("t for iteration $iter = $t")c
                if t>(stopT/10) || iter>iMax #sometimes we set all the initial conditions so this is pointless but whatever
                    println("found a solution with a first step t = $t years in $iter iterations")
                    open("cron_log.txt","a") do f #for cron logging, a flag = append
                        write(f,"found a solution with first step t = $t after $iter iterations\n")
                    end
                    namesList=[newNames,names]
                    return plotInfo,newPhysInfo,nBodies,namesList,colors,t,rad,m
                    accept=true
                else
                    iter+=1
                    #mLocal=getMass(nBodies0) IMF way, not currently used because it's boring
                end
            end
        end
        if numTrials==1
            plotInfo,newPhysInfo,nBodiesGlobal,namesList,colors,t,rad,m=firstStep(copy(nBodies),copy(m),copy(names),copy(colors),stopT,globalT,stopCond[2],dt)
            globalT+=t
            println("number of output files at this step: $(ceil(t/dt)) | nBodies = $nBodiesGlobal")
            push!(tOffsets,globalT) #keep track of offsets for plotting later
            push!(plotList,plotInfo) #keep track of data from each step in master list
            push!(colorsList,colors) #keep track of colors at each step
            push!(physInfoList,[rad,m]) #we don't need to save r because that happens in x & y -- THIS IS INITIAL RAD,M
            push!(physInfoList,[newPhysInfo[2],newPhysInfo[3]]) #THIS IS RAD, M AFTER FIRST STEP
            push!(nBodiesList,nBodiesGlobal) #keep track of number of bodies at this step
            global physInfo=newPhysInfo #swap pointers, make this global so else statement can know about it
        else
            plotInfo,newPhysInfo,nBodiesGlobal,names,colors,t=genNBodyStep(nBodiesGlobal,copy(physInfo),copy(names),copy(colors),[stopT-globalT,stopCond[2]],dt)
            physInfo=newPhysInfo #swap pointers
            rad,m=physInfo[2],physInfo[3] #r is the first thing but we don't need it here -- THIS IS RAD, M AFTER 2+ STEPS
            globalT+=t
            println("number of output files at this step: $(ceil(t/dt)) | nBodies = $nBodiesGlobal")
            push!(tOffsets,globalT) #keep track of offsets for plotting later
            push!(plotList,plotInfo) #keep track of data from each step in master list
            push!(namesList,names) #keep track of names at each step
            push!(colorsList,colors) #keep track of colors at each step
            push!(physInfoList,[rad,m]) #we don't need to save r because that happens in x & y
            push!(nBodiesList,nBodiesGlobal) #keep track of number of bodies at this step
        end
    end
    #note: the bodies, colors, and names list are all 1 "too long" -- since they include an update from the last step, so in plotting loop we go to length(nBodiesList) - 1.
    println("made it $(@sprintf("%.2f",globalT)) years with $nBodiesGlobal surviving")
    return numTrials,plotList,tOffsets,physInfoList,namesList,colorsList,nBodiesList
end

function getInterestingNBody(nBodies,m,names,colors; minTime=0,stopCond=[10,100],dt=0.033,iMax=10,vRange=[-7e3,7e3],posRange=[-50,50]) #units of things in yrs, AU
    #sometimes random conditions result in a really short animation where things
    #just crash into each other/fly away, so this function throws away those
    #comments above from threeBody code -- since I allow collisions now this pretty much always runs all the way through first try but good to have just in case
    yearSec=365*24*3600
    interesting=false
    i=1
    while interesting==false
        nTrials,plotList,tOffsets,physInfoList,namesList,colorsList,nBodiesList=genNBody(nBodies,m,names,colors,stopCond=stopCond,dt=dt,vRange=vRange,posRange=posRange) #evolve a system
        stopT=tOffsets[end-1]+plotList[end][3][end]/yearSec #final end time for system evolved above
        if (stopT)>=minTime #only return if simulation runs for longer than minTime
            println("total time: ",stopT) #tell me how many years we are simulating
            open("cron_log.txt","a") do f #for cron logging (not really relevant for this script but a holdover from threeBody twitter bot script debugging)
                write(f,"$(stopT)\n") #I'm keeeping it anyways because it might be useful in the future if I want to turn this into a bot too
            end
            return nTrials,plotList,tOffsets,physInfoList,namesList,colorsList,nBodiesList
            interesting=true
        elseif i>iMax #computationally expensive so don't want to go forever
            interesting=true #render it anyways I guess because sometimes it's fun?
            println("did not find interesting solution in number of tries allotted, running anyways")
            println("total time: ",stopT) #how many years simulation runs for
            open("cron_log.txt","a") do f #for cron logging
                write(f,"$(stopT)\n")
            end
            return nTrials,plotList,tOffsets,physInfoList,namesList,colorsList,nBodiesList
        end
        i+=1
    end
end

function getRatioRight(ratio,dx,dy)
    if (dx/dy)!=ratio
        if dx>(ratio*dy)
            dy=dx/ratio
        else
            dx=dy*ratio
        end
    end
    return dx,dy
end

function getLims(xList,yList,padding,maxFrame,oldCenter,landscape) #determines plot limits at each frame, padding in units of pos
    xMin=minimum(xList) #where xList contains the current x position of all bodies
    xMax=maximum(xList) #ditto but max
    dx=xMax-xMin
    yMin=minimum(yList) #same as above but for y
    yMax=maximum(yList)
    dy=yMax-yMin
    horizontalExtraRatio=1
    if landscape==1
        horizontalExtraRatio=1920/1080 #landscape picture has extra space in x direction
    end
    centerX,centerY=sum(xList)/length(xList),sum(yList)/length(yList)
    dx,dy=getRatioRight(horizontalExtraRatio,dx,dy)
    xlims=[xMin-padding*horizontalExtraRatio,xMin+dx+padding*horizontalExtraRatio]
    ylims=[yMin-padding,yMin+dy+padding]
    return xlims,ylims,[centerX,centerY]
end

function makeCircleVals(r,center=[0,0]) #this function generates circle markers that are to scale with plot
    xOffset=center[1]
    yOffset=center[2]
    xVals=[r*cos(i)+xOffset for i=0:(pi/64):(2*pi)]
    yVals=[r*sin(i)+yOffset for i=0:(pi/64):(2*pi)]
    return xVals,yVals
end

#this new way runs significantly faster (~2x improvement over @anim)
#Downside is it spams folder with png images of every frame and must manually compile with ffmpeg
function plotSection(landscape,sectionNum,backData,oldI,oldColors,offsets,dt,nBodies,plotInfo,physInfo,labels,colors,maxFrame;slowDown=1)
    colorSymbols=[Symbol(color) for color in colors] #change strings to symbols for plot args
    oldColorSymbols=[Symbol(color) for color in oldColors]
    skipRate=Int(floor(1/dt/(30*slowDown))) #30 fps, slowDown = sloMo (ie a value of 2 makes this run at half speed)
    rad=physInfo[1]
    m=physInfo[2]
    xData=plotInfo[1]
    yData=plotInfo[2]
    t=plotInfo[3]
    tOffset=offsets[1]
    plotNum=offsets[2]
    I=0
    listInd=0
    center=[0.,0.] #not actually the center but this won't get used right away and should be overwritten before needed so doesn't matter
    limList=[]
    oscillatingCount=0
    oscillating=false
    ratio=1
    if landscape==1
        ratio=1920/1080
    end
    ejectBan=[]
    for n=1:nBodies
        push!(ejectBan,[0,0]) #initialize banBool,Counter for each body
    end
    for i=1:skipRate:length(t) #this makes animation scale ~1 sec/year with other conditions
        GR.inline("png") #added to eneable cron/jobber compatibility, also this makes frames generate WAY faster? Prior to adding this when run from cron/jobber frames would stop generating at 408 for some reason.
        gr(legendfontcolor = plot_color(:white)) #legendfontcolor=:white plot arg broken right now (at least in this backend)
        p=plot(size=(1024,1024)) #initialize plot
        if landscape==1
            p=plot(size=(1920,1080)) #FHD landscape
        end
        if sectionNum>1  #don't need to do this forever since they decay to 0 anyways
            for n=1:length(backData) #old list has +1 bodies
                p=plot!(backData[n][1]./1.5e11,backData[n][2]./1.5e11,label="",linecolor=oldColorSymbols[n],linealpha=max.((1:Int(floor(skipRate/10)):oldI) .+ 10000 .- (oldI+i),1000)/10000)
            end
        end
        print("$(@sprintf("%.2f",i/length(t)*100)) % complete\r") #output percent tracker
        x=[]
        y=[]
        for n=1:nBodies
            if abs(xData[n][i])/1.5e11 <= (maxFrame*1.25*ratio + abs(center[1])) && abs(yData[n][i])/1.5e11 <= (maxFrame*1.25 + abs(center[2]))
                if ejectBan[n][1]==0 || ejectBan[n][2]>60 #let it be considered again after 60 frames
                    push!(x,xData[n][i]/1.5e11)
                    push!(y,yData[n][i]/1.5e11)
                    ejectBan[n][1]=0
                    ejectBan[n][2]=0
                end
            else
                ejectBan[n][1]=1
                ejectBan[n][2]+=1 #it's stayed ejected another frame
            end
        end
        if length(x) <= 1
            println("all bodies ejected, stopping plotting")
            return 0
        end
        oldCenter=copy(center)
        limx,limy,center=getLims(x,y,20,maxFrame,oldCenter,landscape) #20 AU padding
        dx,dy=(limx[2]-limx[1]),(limy[2]-limy[1])
        if listInd>2 #this block will hopefully prevent the camera from oscillating back and forth..? (for a 10 frames right now)
            oldLimx,oldLimy=limList[listInd][1],limList[listInd][2] #one back
            oldLimx2,oldLimy2=limList[listInd-1][1],limList[listInd-1][2] #two back
            oldDx2,oldDy2=(oldLimx2[2]-oldLimx2[1]),(oldLimy2[2]-oldLimy2[1])
            oldDx,oldDy=(oldLimx[2]-oldLimx[1]),(oldLimy[2]-oldLimy[1])
            if dx>oldDx && oldDx2>oldDx || dx<oldDx && oldDx2<oldDx/1.02#.05
                dx=oldDx*1.02 #fix trajectory for a set amt of frames to prevent bounciness
                dy=oldDy*1.02 #always opt for more space, but increase at slow rate
                if dx>oldDx && oldDx2>oldDx
                    dx=oldDx*0.98
                    dy=oldDy*0.98
                end
                oscillating=true
                oscillatingCount+=1
                if oscillatingCount>30
                    oscillating=false
                    oscillatingCount=0
                end
            elseif dy>oldDy && oldDy2>oldDy || dy<oldDy && oldDy2<oldDy/1.02#.05
                dx=oldDx*1.02
                dy=oldDy*1.02
                if dy>oldDy && oldDy2>oldDy
                    dx=oldDx*0.98
                    dy=oldDy*0.98
                end
                oscillating=true
                oscillatingCount+=1
                if oscillatingCount>30
                    oscillating=false
                    oscillatingCount=0
                end
            else
                if oscillating==true
                    dx=oldDx*1.005#.01
                    dy=oldDy*1.005#.01
                    oscillatingCount+=1
                    if oscillatingCount>30 #1 sec at 30 FPS
                        oscillating=false #don't want to freeze the frame forever...
                        oscillatingCount=0
                    end
                end
            end
        end
        dx,dy=getRatioRight(ratio,dx,dy)
        if i>1
            oldLimx,oldLimy=limList[listInd][1],limList[listInd][2]
            oldDx,oldDy=oldLimx[2]-oldLimx[1],oldLimy[2]-oldLimy[1]
            if dx/oldDx<0.98 #frame shrunk more than 2%
                limx[1]=oldCenter[1]-oldDx*0.98/2
                limx[2]=oldCenter[1]+oldDx*0.98/2
            elseif dx/oldDx>1.02 #grew more than 2%
                limx[1]=oldCenter[1]-oldDx*1.02/2
                limx[2]=oldCenter[1]+oldDx*1.02/2
            elseif dy/oldDy<0.98
                limy[1]=oldCenter[2]-oldDy*0.98/2
                limy[2]=oldCenter[2]+oldDy*0.98/2
            elseif dy/oldDy>1.02
                limy[1]=oldCenter[2]-oldDy*1.02/2
                limy[2]=oldCenter[2]+oldDy*1.02/2
            end
        end
        listInd+=1
        dx,dy=(limx[2]-limx[1]),(limy[2]-limy[1])
        dx,dy=getRatioRight(ratio,dx,dy)
        limx[2]=limx[1]+dx
        limy[2]=limy[1]+dy
        push!(limList,[limx,limy])
        for n=1:nBodies
            p=plot!(xData[n][1:Int(floor(skipRate/10)):i]./1.5e11,yData[n][1:Int(floor(skipRate/10)):i]./1.5e11,label="",linecolor=colorSymbols[n],linealpha=max.((1:Int(floor(skipRate/10)):i) .+ 10000 .- i,1000)/10000)
        end
        p=scatter!(starsX,starsY,markercolor=:white,markersize=:1,label="") #fake background stars
        for n=1:nBodies
            currentRad=rad[n]
            plotLabel=labels[n]
            if split(labels[n])[end]=="hole"
                fillColor=:black
                plotLabel=string(plotLabel," (enlarged 100,000x)")
                currentRad*=100000 #black hole is just very smol
            else
                fillColor=colorSymbols[n]
            end
            circleX,circleY=makeCircleVals(currentRad,[xData[n][i],yData[n][i]])
            if xData[n][i]/1.5e11 > limx[2] || yData[n][i]/1.5e11 > limy[2] || xData[n][i]/1.5e11 < limx[1] || yData[n][i]/1.5e11 < limy[1] #it's out of the frame
                plotLabel=string(plotLabel," (ejected)")
            end
            p=plot!(circleX./1.5e11,circleY./1.5e11,label=plotLabel,linecolor=colorSymbols[n],fill=true,fillcolor=fillColor)
        end
        p=plot!(background_color=:black,background_color_legend=:transparent,foreground_color_legend=:transparent,
            background_color_outside=:white,aspect_ratio=:equal,legendtitlefontcolor=:white) #formatting for plot frame
        currentT=t[i]/365/24/3600+tOffset
        titleString="Random $nBodies-Body Problem\nt: $(@sprintf("%0.2f",currentT)) years after start"
        if landscape==1
            titleString="Random $nBodies-Body Problem  |  t: $(@sprintf("%0.2f",currentT)) years after start"
        end
        p=plot!(xlabel="x: AU",ylabel="y: AU",title=titleString,
            legend=:best,xaxis=("x: AU",(limx[1],limx[2]),font(10,"Courier")),yaxis=("y: AU",(limy[1],limy[2]),font(10,"Courier")),
            grid=false,titlefont=font(18,"Courier"),legendfontsize=9,legendtitle="Mass (in solar masses)",legendtitlefontsize=10,top_margin=2mm,bottom_margin=2mm) #add in axes/title/legend with formatting
        plotNum+=1
        png(p,@sprintf("tmpPlots2/frame_%06d.png",plotNum))
        closeall() #close plots
        I+=skipRate
    end
    if sectionNum==1
        for n=1:nBodies
            xBack=xData[n][1:Int(floor(skipRate/10)):end]
            yBack=yData[n][1:Int(floor(skipRate/10)):end]
            push!(backData,[xBack,yBack]) #initialize backData
        end
    else
        for i=1:length(colors)
            currentColor=colors[i] #color is really a placeholder for which body this is
            for j=1:length(oldColors)
                if currentColor==oldColors[j] #this means we've found the original index (j)
                    xBack=xData[i][1:Int(floor(skipRate/10)):end]
                    yBack=yData[i][1:Int(floor(skipRate/10)):end]
                    backData[j][1]=vcat(backData[j][1],xBack) #backData has info from all bodies so we need to make sure to keep it consistent
                    backData[j][2]=vcat(backData[j][2],yBack) #stitch together new piece with old pieces (where applicable to surviving bodies)
                end
            end
        end
    end
    return plotNum,backData,I
end

function plotAll(landscape,nBodiesList,plotList,physInfoList,namesList,colorsList,maxFrame,tOffsets,dt;slowDown=1)
    frameOffset=0 #start at one because frame numbers start at 1
    backData=[]
    oldI=0
    for i=1:(length(nBodiesList)-1) #-1 because this list has n+1 things (includes body count after last step, which we don't need)
        currentNBodies=nBodiesList[i]
        println("plotting step $i of $(length(nBodiesList)-1) with $currentNBodies bodies")
        currentPlotData=plotList[i]
        currentPhysInfo=physInfoList[i]
        currentNames=namesList[i]
        println("names at step $i = $currentNames")
        currentColors=colorsList[i]
        if i>1
            oldColors=colorsList[1]
        else
            oldColors=[]
        end
        currentTOffset=tOffsets[i]
        currentFrame,newBackData,IPlus=plotSection(landscape,i,backData,oldI,oldColors,[currentTOffset,frameOffset],dt,
                                        currentNBodies,currentPlotData,currentPhysInfo,currentNames,currentColors,
                                        maxFrame,slowDown=slowDown)
        backData=newBackData
        oldI+=IPlus
        frameOffset=currentFrame
    end
end

# STEP 1: get nBodies, colors, and labels
nBodies=parse(Int,ARGS[1])
println("running simulation for $nBodies bodies")
validColors=[]
open("juliaColors.txt","r") do f
    for line in eachline(f)
        push!(validColors,line)
    end
end

colorBool=parse(Int,ARGS[2])
function getUniqueColors(nBodies,validColors)
    accept=false
    while accept==false
        global randInd=rand(1:length(validColors),nBodies) #global because julia scope and I'm too lazy to do this right
        #println("I'm stuck here")
        println("$(length(unique(randInd))), $(length(randInd))")
        if length(unique(randInd))==length(randInd)
            accept=true #make sure that all entries are unique so no colors are duplicated
            break
        end
    end
    colors=[validColors[i] for i in randInd]
    return colors
end
if colorBool==1
    println("let's pick colors!")
    colors=[]
    for n=1:nBodies
        accept=false
        while accept==false
            print("please enter a valid color ($n/$nBodies): ")
            color=readline()
            if color in validColors
                push!(colors,color)
                accept=true
            else
                println("I'm sorry, I don't know that color")
            end
        end
    end
elseif colorBool==2 #a nice set of color presets I like
    colorChoices=["dodgerblue","blueviolet","lightseagreen","gold","crimson","silver","hotpink",
                    "orange","thistle","yellowgreen","rosybrown","peachpuff","darksalmon","deeppink",
                    "paleturquoise","orchid","orangered","limegreen","goldenrod","fuchsia","lightsteelblue"]
    colors=getUniqueColors(nBodies,colorChoices)
else
    println("using randomly generated colors")
    colors=getUniqueColors(nBodies,validColors)
end

labelBool=parse(Int,ARGS[3])
if labelBool==1
    println("let's make some stars!")
    labels=[]
    mStart=[]
    for n=1:nBodies
        print("please enter a mass (solar mass units) for body $n/$nBodies: ")
        name=readline()
        push!(labels,name)
        push!(mStart,parse(Float64,name))
    end
else
    mStart=rand(1:1500,nBodies)./10 #n random masses between 0.1 and 150 solar masses
    #mStart=getMass(nBodies) #IMF way, but boring so not used right now
    labels=["$(mStart[i])" for i=1:nBodies]
end

names=copy(labels)
nBodies0=copy(nBodies)

#STEP 2: generate the data with given parameters (may add dt, stopCond, posRange as user-input things later)
nTrials,plotList,tOffsets,physInfoList,namesList,colorsList,nBodiesList=getInterestingNBody(nBodies,copy(mStart),names,colors,dt=0.00005,stopCond=[50,500],minTime=40,posRange=[-50,50],vRange=[-7e3,7e3])
#nBodiesList=[nBodies0-i for i=0:(nTrials-1)] #function doesn't return a list

#adding fake stars
function getMax(plotList,ind)
    MAX=0
    for i=1:length(plotList)
        for j=1:length(plotList[end][ind])
            localMax=maximum(plotList[i][ind][j])
            if localMax>MAX
                MAX=localMax
            end
        end
    end
    return MAX/1.5e11
end
function getMin(plotList,ind)
    MIN=0
    for i=1:length(plotList)
        for j=1:length(plotList[end][ind])
            localMin=minimum(plotList[i][ind][j])
            if localMin<MIN
                MIN=localMin
            end
        end
    end
    return MIN/1.5e11
end
minMax=zeros(4)
minMax[1],minMax[2]=getMax(plotList,1),getMax(plotList,2)
minMax[3],minMax[4]=getMin(plotList,1),getMin(plotList,2)
boxMin=floor(minimum(minMax))-500 #give 500 AU cushion for the full frame
boxMax=ceil(maximum(minMax))+500
bigNess=Int(ceil((boxMax-boxMin)/200)) #used to do 2500 in 200 AU
function initStars(bigNess)
    try
        numStars=2000*bigNess
        starsX=zeros(numStars)
        starsY=zeros(numStars)
        return numStars,starsX,starsY
    catch
        numStars=200000 #a big number but not so big it overloads RAM
        starsX=zeros(numStars)
        starsY=zeros(numStars)
        return numStars,starsX,starsY
    end
end
numStars,starsX,starsY=initStars(bigNess)
for i=1:numStars
    num=rand(boxMin:boxMax,2) #box size is 70 AU but we need some extra padding for movement
    starsX[i]=num[1]
    starsY[i]=num[2]
end
landscape=parse(Int,ARGS[4])
#STEP 3: plot data with parameters (note that dt and maxFrame must be duplicated as is, should probably have user pass them in and store to var)
plotAll(landscape,nBodiesList,plotList,physInfoList,namesList,colorsList,100,tOffsets,0.00005,slowDown=1)
