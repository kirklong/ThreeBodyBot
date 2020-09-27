#!/usr/bin/env julia
using Plots, Random, Printf

function initCondGen() #get random initial conditions for mass/radius, position, and velocity
    function getMass(nBodies) #generate random masses that better reflect actual stellar populations
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
    rad=m.^0.8 #3 radii based on masses in solar units
    m=m.*2e30 #convert to SI kg
    rad=rad.*7e8 #convert to SI m
    pos1=rand(-10:10,2) #random initial coordinates x & y for first body, AU
    function genPos2(pos1)
        accept2=false
        while accept2==false
            pos2=rand(-10:10,2) #random initial coordinates for second body, AU
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
            pos3=rand(-10:10,2) #random initial coordinates for third body, AU
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
    v=rand(-7e3:7e3,6) #random x & y velocities with mag between -10 & 10 km/s, totally arbitrary...
    #r=[x1,y1,x2,y2,x3,y3,v1x,v1y,v2x,v2y,v3x,v3y]
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
    dx1=-(c2*(x1-x2)/(r1_2^3))-(c3*(x1-x3)/(r1_3^3)) #d^2x/dt^2 for 1, m/s after * dt
    dx2=-(c1*(x2-x1)/(r1_2^3))-(c3*(x2-x3)/(r2_3^3)) #d^2x/dt^2 for 2, m/s
    dx3=-(c1*(x3-x1)/(r1_3^3))-(c2*(x3-x2)/(r2_3^3)) #d^2x/dt^2 for 3, m/s
    dy1=-(c2*(y1-y2)/(r1_2^3))-(c3*(y1-y3)/(r1_3^3)) #d^2y/dt^2 for 1, m/s
    dy2=-(c1*(y2-y1)/(r1_2^3))-(c3*(y2-y3)/(r2_3^3)) #d^2y/dt^2 for 2, m/s
    dy3=-(c1*(y3-y1)/(r1_3^3))-(c2*(y3-y2)/(r2_3^3)) #d^2y/dt^2 for 3, m/s
    global energy
    U=-G*M1*M2/r1_2-G*M2*M3/r2_3-G*M1*M3/r1_3
    K=0.5*M1*(v1X^2+v1Y^2)+0.5*M2*(v2X^2+v2Y^2)+0.5*M3*(v3X^2+v3Y^2)
    if energyBool==1
        push!(energy,K+U) #total system energy
    end
    return [v1X,v1Y,v2X,v2Y,v3X,v3Y,dx1,dy1,dx2,dy2,dx3,dy3]
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
    min12=rad[1]+rad[2]
    min13=rad[1]+rad[3]
    min23=rad[2]+rad[3]
    i=1
    stopT=maximum(t)
    collisionBool=false
    #implement RK4 to model solutions to differential equations
    while stop==false
        if currentT==stopT || currentT>stopT #in case of rounding error or something
            stop=true
        elseif i>(numSteps+1) #inf loop failsafe
            stop=true
            println("error: shouldn't have gotten here")
        else
            x1[i]=r[1]
            y1[i]=r[2]
            x2[i]=r[3]
            y2[i]=r[4]
            x3[i]=r[5]
            y3[i]=r[6]

            k1=stepSize*dR(r,m,energyBool=1)
            k2=stepSize*dR(r.+0.5.*k1,m)
            k3=stepSize*dR(r.+0.5.*k2,m)
            k4=stepSize*dR(r.+k3,m)
            r+=(k1.+2.0*k2.+2.0.*k3.+k4)./6

            #check separation after each dt step
            sep12=sqrt((x1[i]-x2[i])^2+(y1[i]-y2[i])^2)
            sep13=sqrt((x1[i]-x3[i])^2+(y1[i]-y3[i])^2)
            sep23=sqrt((x3[i]-x2[i])^2+(y3[i]-y2[i])^2)

            if sep12<min12 || sep13<min13 || sep23<min23 || sep12>sepStop || sep13>sepStop || sep23>sepStop
                if sep12<min12 || sep13<min13 || sep23<min23
                    collisionBool=true
                else
                    collisionBool=false
                end
                stop=true #stop if collision happens or body is ejected
                t=range(0,stop=currentT,length=i) #t should match pos vectors
                x1=x1[1:i] #don't want trailing zeros
                y1=y1[1:i]
                x2=x2[1:i]
                y2=y2[1:i]
                x3=x3[1:i]
                y3=y3[1:i]
            end
            i+=1
            currentT+=stepSize #next step
        end
    end
    return [x1,y1,x2,y2,x3,y3], t, m, rad, collisionBool
end

function getInteresting3Body(minTime=0) #in years, defaults to 0
    #sometimes random conditions result in a really short animation where things
    #just crash into each other/fly away, so this function throws away those
    yearSec=365*24*3600
    interesting=false
    i=1
    while interesting==false
        global energy=[] #re-initialize empty energy array
        plotData,t,m,rad,collisionBool=gen3Body([50,150],500000)
        if (maximum(t)/yearSec)>minTime #only return if simulation runs for longer than minTime
            println(maximum(t)/yearSec) #tell me how many years we are simulating
            open("cron_log.txt","a") do f #for cron logging, a flag = append
                write(f,"$(maximum(t)/yearSec)\n")
            end
            return plotData,t,m,rad,collisionBool
            interesting=true
        elseif i>1999 #computationally expensive so don't want to go forever
            interesting=true #render it anyways I guess because sometimes it's fun?
            println("did not find interesting solution in number of tries allotted, running anyways")
            println(maximum(t)/yearSec) #how many years simulation runs for
            open("cron_log.txt","a") do f #for cron logging
                write(f,"found a solution with t = $(maximum(t)/yearSec) in $i iterations\n")
            end
            return plotData,t,m,rad,collisionBool
        end
        i+=1
    end
end

transitionPoint=false
extraX=[0.,0.]
extraY=[0.,0.]
orbitingList=[0]
function getLims(pos,padding,m) #determines plot limits at each frame, padding in units of pos
    x=[pos[1],pos[3],pos[5]]
    xMin=minimum(x)
    xMax=maximum(x)
    dx=xMax-xMin
    y=[pos[2],pos[4],pos[6]]
    yMin=minimum(y)
    yMax=maximum(y)
    dy=yMax-yMin
    d1_2=sqrt((x[1]-x[2])^2 + (y[1]-y[2])^2)
    d1_3=sqrt((x[1]-x[3])^2 + (y[1]-y[3])^2)
    d2_3=sqrt((x[2]-x[3])^2 + (y[2]-y[3])^2)
    orbiting=false
    global transitionPoint #note that all these globals are really bad/lazy programming practice but whatever
    global extraX
    global extraY
    global orbitingList
    function setExtraSpacing(cmX,cmY,xMax,xMin,yMax,yMin,xNew,yNew) #set global variables to try to smooth out transition points
        global transitionPoint
        global extraX
        global extraY
        if transitionPoint==false
            transitionPoint=true
            if xMax!=maximum(xNew)
                extraX=[0,xMax-cmX] #the difference between new cm position and wherever frame was when transition happened
            elseif xMin!=minimum(xNew)
                extraX=[xMin-cmX,0] #same as above but negative in this case, extra spacing to the left
            end
            if yMax!=maximum(yNew)
                extraY=[0,yMax-cmY] #the difference between new cm position and wherever frame was when transition happened
            elseif yMin!=minimum(yNew)
                extraY=[yMin-cmY,0] #same as above but negative in this case, extra spacing down
            end
        else
            extraX=[0.,0.]
            extraY=[0.,0.]
        end
    end
    if d1_2/d2_3 > 2 && d1_3/d2_3 > 2 #objects 2 and 3 are orbiting?
        orbiting=true
        cmX=(m[2]*x[2]+m[3]*x[3])/(m[2]+m[3]) #get centers of mass to use in limit calculations to prevent oscillations
        cmY=(m[2]*y[2]+m[3]*y[3])/(m[2]+m[3])
        xNew=[x[1],cmX]
        yNew=[y[1],cmY]
        setExtraSpacing(cmX,cmY,xMax,xMin,yMax,yMin,xNew,yNew)
    elseif d2_3/d1_2 > 2 && d1_3/d1_2 > 2 #objects 2 and 1 are orbiting?
        orbiting=true
        cmX=(m[2]*x[2]+m[1]*x[1])/(m[2]+m[1]) #get centers of mass
        cmY=(m[2]*y[2]+m[1]*y[1])/(m[2]+m[1])
        xNew=[x[3],cmX]
        yNew=[y[3],cmY]
        setExtraSpacing(cmX,cmY,xMax,xMin,yMax,yMin,xNew,yNew)
    elseif d1_2/d1_3 > 2 && d2_3/d1_3 > 2 #objects 1 and 3 are orbiting?
        orbiting=true
        cmX=(m[1]*x[1]+m[3]*x[3])/(m[1]+m[3]) #get centers of mass
        cmY=(m[1]*y[1]+m[3]*y[3])/(m[1]+m[3])
        xNew=[x[2],cmX]
        yNew=[y[2],cmY]
        setExtraSpacing(cmX,cmY,xMax,xMin,yMax,yMin,xNew,yNew)
    end
    if orbiting==true #repeat above calculation using CM coordinates
        xMin=minimum(xNew)+extraX[1] #new xMin, including left shift to make transition "smooth"
        xMax=maximum(xNew)+extraX[2] #new xMax
        dx=xMax-xMin
        yMin=minimum(yNew)+extraY[1] #new yMin
        yMax=maximum(yNew)+extraY[2] #new yMax
        dy=yMax-yMin
        push!(orbitingList,1)
    elseif orbiting==false
        if orbitingList[end]==1 #last frame was orbiting
            transitionPoint=false
        end
        push!(orbitingList,0)
    end
    if dx>dy
        #use x for square
        xlims=[xMin-padding,xMax+padding]
        ylims=[yMin-padding,yMin+dx+padding]
    else
        #use y for square
        xlims=[xMin-padding,xMin+dy+padding]
        ylims=[yMin-padding,yMax+padding]
    end
    return xlims,ylims,[sum(x)/3,sum(y)/3]
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

function makeCircleVals(r,center=[0,0])
    xOffset=center[1]
    yOffset=center[2]
    xVals=[r*cos(i)+xOffset for i=0:(pi/64):(2*pi)]
    yVals=[r*sin(i)+yOffset for i=0:(pi/64):(2*pi)]
    return xVals,yVals
end

plotData,t,m,rad,collisionBool=getInteresting3Body(15)
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

#this new way runs significantly faster (~2x improvement over @anim)
#Downside is it spams folder with png images of every frame and must manually compile with ffmpeg
#Comment out and use older way (after this below) if performance/specific formatting is not an issue
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

#plotLoadPath="/home/kirk/Documents/3Body/tmpPlots/"
#threeBodyAnim=Animation(plotLoadPath,String[])
global frameNum=1
stop=length(t)
if collisionBool==true
    stop=length(t)-600
end
global listInd=0
limList=[]
global ratio=1
println("energy loss = $((energy[end]-energy[1])/energy[1]*100) %")
for i=1:333:stop #this makes animation scale ~1 sec/year with other conditions
    GR.inline("png") #added to eneable cron/jobber compatibility, also this makes frames generate WAY faster? Prior to adding this when run from cron/jobber frames would stop generating at 408 for some reason.
    gr(legendfontcolor = plot_color(:white)) #legendfontcolor=:white plot arg broken right now (at least in this backend)
    print("$(@sprintf("%.2f",i/length(t)*100)) % complete\r") #output percent tracker
    pos=[plotData[1][i],plotData[2][i],plotData[3][i],plotData[4][i],plotData[5][i],plotData[6][i]] #current pos
    limx,limy,center=getLims(pos./1.5e11,15,m) #convert to AU, 10 AU padding
    oldCenter=copy(center)
    dx,dy=(limx[2]-limx[1]),(limy[2]-limy[1])
    global listInd #in Julia scope it a for loop like this doesn't know about variables declared outside the loop
    global ratio
    dx,dy=getRatioRight(ratio,dx,dy)
    if listInd>1
        oldLimx,oldLimy=limList[listInd][1],limList[listInd][2]
        oldDx,oldDy=oldLimx[2]-oldLimx[1],oldLimy[2]-oldLimy[1]
        if dx/oldDx<0.97 #frame shrunk more than 5%
            limx[1]=oldCenter[1]-oldDx*0.97/2
            limx[2]=oldCenter[1]+oldDx*0.97/2
        elseif dx/oldDx>1.03 #grew more than 5%
            limx[1]=oldCenter[1]-oldDx*1.03/2
            limx[2]=oldCenter[1]+oldDx*1.03/2
        elseif dy/oldDy<0.97
            limy[1]=oldCenter[2]-oldDy*0.97/2
            limy[2]=oldCenter[2]+oldDy*0.97/2
        elseif dy/oldDy>1.03
            limy[1]=oldCenter[2]-oldDy*1.03/2
            limy[2]=oldCenter[2]+oldDy*1.03/2
        end
    end
    listInd+=1
    dx,dy=(limx[2]-limx[1]),(limy[2]-limy[1])
    dx,dy=getRatioRight(ratio,dx,dy)
    limx[2]=limx[1]+dx
    limy[2]=limy[1]+dy
    push!(limList,[limx,limy])
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
    p=plot!(xlabel="x: AU",ylabel="y: AU",title="Random Three-Body Problem\nt: $(@sprintf("%0.2f",t[i]/365/24/3600)) years after start",
        legend=:best,xaxis=("x: AU",(limx[1],limx[2]),font(9,"Courier")),yaxis=("y: AU",(limy[1],limy[2]),font(9,"Courier")),
        grid=false,titlefont=font(14,"Courier"),size=(720,721),legendfontsize=8,legendtitle="Mass (in solar masses)",legendtitlefontsize=8,legendtitlefont="Courier") #add in axes/title/legend with formatting
    png(p,@sprintf("tmpPlots/frame_%06d.png",frameNum))
    global frameNum+=1
    closeall() #close plots
end
if collisionBool==true #this condition makes 2 seconds of slo-mo right before the collision
    println("making collision cam")
    for i=1:10:600
        GR.inline("png") #added to eneable cron/jobber compatibility, also this makes frames generate WAY faster? Prior to adding this when run from cron/jobber frames would stop generating at 408 for some reason.
        gr(legendfontcolor = plot_color(:white)) #legendfontcolor=:white plot arg broken right now (at least in this backend)
        print("$(@sprintf("%.2f",i/600*100)) % complete\r") #output percent tracker
        pos=[plotData[1][end-(600-i)],plotData[2][end-(600-i)],plotData[3][end-(600-i)],plotData[4][end-(600-i)],plotData[5][end-(600-i)],plotData[6][end-(600-i)]] #current pos
        limx,limy,center=getLims(pos./1.5e11,15,m) #convert to AU, 15 AU padding
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
        p=annotate!((limx[1]+(limx[2]-limx[1])/20,limy[2]-(limy[2]-limy[1])/20,Plots.text("COLLISION CAM (slo-mo x 33)",12,"Courier",:orange,:left)))
        png(p,@sprintf("tmpPlots/frame_%06d.png",frameNum))
        global frameNum+=1
        closeall() #close plots
    end
end

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
#     limx,limy=getLims(pos./1.5e11,5) #convert to AU, 5 AU padding
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
