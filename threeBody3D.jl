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
    pos1=rand(-10:10,3) #random initial coordinates x & y for first body, AU
    function genPos2(pos1)
        accept2=false
        while accept2==false
            pos2=rand(-10:10,3) #random initial coordinates for second body, AU
            dist21=sqrt((pos1[1]-pos2[1])^2+(pos1[2]-pos2[2])^2+(pos1[3]-pos2[3])^2)
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
            pos3=rand(-10:10,3) #random initial coordinates for third body, AU
            dist31=sqrt((pos1[1]-pos3[1])^2+(pos1[2]-pos3[2])^2+(pos1[3]-pos3[3])^2)
            dist32=sqrt((pos2[1]-pos3[1])^2+(pos2[2]-pos3[2])^2+(pos2[3]-pos3[3])^2)
            if (dist31*1.5e11)>(rad[1]+rad[3]) && (dist32*1.5e11)>(rad[2]+rad[3]) #3rd isn't touching either
                accept3=true
                return pos3
            end
        end
    end
    pos3=genPos3(pos1,pos2)
    pos=[pos1[1],pos1[2],pos1[3],pos2[1],pos2[2],pos2[3],pos3[1],pos3[2],pos3[3]].*1.5e11 #convert accepted positions to SI, m
    v=rand(-7e3:7e3,9) #random xyz velocities with mag between -10 & 10 km/s, totally arbitrary...
    #r=[x1,y1,x2,y2,x3,y3,v1x,v1y,v2x,v2y,v3x,v3y]
    r=[pos[1],pos[2],pos[3],pos[4],pos[5],pos[6],pos[7],pos[8],pos[9],v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8],v[9]]
    open("initCond.txt","w") do f #save initial conditions to file in folder where script is run
        write(f,"m1=$(@sprintf("%.1f",(m[1]/2e30))) m2=$(@sprintf("%.1f",(m[2]/2e30))) m3=$(@sprintf("%.1f",(m[3]/2e30))) (solar masses)\nv1x=$(v[1]/1e3) v1y=$(v[2]/1e3) v1z=$(v[3]/1e3) v2x=$(v[4]/1e3) v2y=$(v[5]/1e3) v2z=$(v[6]/1e3) v3x=$(v[7]/1e3) v3y=$(v[8]/1e3) v3z=$(v[9]/1e3) (km/s)\nx1=$(pos1[1]) y1=$(pos1[2]) z1=$(pos1[3]) x2=$(pos2[1]) y2=$(pos2[2]) z2=$(pos2[3]) x3=$(pos3[1]) y3=$(pos3[2]) z3=$(pos3[3]) (AU from center)")
    end
    return r, rad, m
end

function dR(r,m) #function we will use RK4 on to approximate solution
    G=6.67408313131313e-11# Nm^2/kg^2
    M1,M2,M3=m[1],m[2],m[3] #kg
    x1,x2,x3=r[1],r[4],r[7] #m
    y1,y2,y3=r[2],r[5],r[8] #m
    z1,z2,z3=r[3],r[6],r[9]
    c1,c2,c3=G*M1,G*M2,G*M3 #Nm^2/kg
    r1_2=sqrt((x1-x2)^2+(y1-y2)^2+(z1-z2)^2) #distance from 1->2, m
    r1_3=sqrt((x1-x3)^2+(y1-y3)^2+(z1-z2)^2) #distance from 1->3, m
    r2_3=sqrt((x2-x3)^2+(y2-y3)^2+(z1-z2)^2) #distance from 2->3, m

    v1X,v2X,v3X=r[10],r[13],r[16] #these are our change in position after dt (dr/dt*dt=dr)
    v1Y,v2Y,v3Y=r[11],r[14],r[17] #m after * dt
    v1Z,v2Z,v3Z=r[12],r[15],r[18]

    #get change in velocity from accelerations (d^2r/dt^2*dt=dv/dt*dt=dv)
    dx1=-(c2*(x1-x2)/(r1_2^3))-(c3*(x1-x3)/(r1_3^3)) #d^2x/dt^2 for 1, m/s after * dt
    dx2=-(c1*(x2-x1)/(r1_2^3))-(c3*(x2-x3)/(r2_3^3)) #d^2x/dt^2 for 2, m/s
    dx3=-(c1*(x3-x1)/(r1_3^3))-(c2*(x3-x2)/(r2_3^3)) #d^2x/dt^2 for 3, m/s
    dy1=-(c2*(y1-y2)/(r1_2^3))-(c3*(y1-y3)/(r1_3^3)) #d^2y/dt^2 for 1, m/s
    dy2=-(c1*(y2-y1)/(r1_2^3))-(c3*(y2-y3)/(r2_3^3)) #d^2y/dt^2 for 2, m/s
    dy3=-(c1*(y3-y1)/(r1_3^3))-(c2*(y3-y2)/(r2_3^3)) #d^2y/dt^2 for 3, m/s
    dz1=-(c2*(z1-z2)/(r1_2^3))-(c3*(z1-z3)/(r1_3^3)) #d^2y/dt^2 for 1, m/s
    dz2=-(c1*(z2-z1)/(r1_2^3))-(c3*(z2-z3)/(r2_3^3)) #d^2y/dt^2 for 2, m/s
    dz3=-(c1*(z3-z1)/(r1_3^3))-(c2*(z3-z2)/(r2_3^3)) #d^2y/dt^2 for 3, m/s

    return [v1X,v1Y,v1Z,v2X,v2Y,v2Z,v3X,v3Y,v3Z,dx1,dy1,dz1,dx2,dy2,dz2,dx3,dy3,dz3]
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
    z1=zeros(length(t))
    x2=zeros(length(t))
    y2=zeros(length(t))
    z2=zeros(length(t))
    x3=zeros(length(t))
    y3=zeros(length(t))
    z3=zeros(length(t))
    r,rad,m=initCondGen()
    min12=rad[1]+rad[2]
    min13=rad[1]+rad[3]
    min23=rad[2]+rad[3]
    i=1
    stopT=maximum(t)

    #implement RK4 to model solutions to differential equations
    while stop==false
        if currentT==stopT || currentT>stopT #in case of rounding error or something
            stop=true
        elseif i>numSteps+1 #inf loop failsafe
            stop=true
            println("error: shouldn't have gotten here")
        else
            x1[i]=r[1]
            y1[i]=r[2]
            z1[i]=r[3]
            x2[i]=r[4]
            y2[i]=r[5]
            z2[i]=r[6]
            x3[i]=r[7]
            y3[i]=r[8]
            z3[i]=r[9]

            k1=stepSize*dR(r,m)
            k2=stepSize*dR(r.+0.5.*k1,m)
            k3=stepSize*dR(r.+0.5.*k2,m)
            k4=stepSize*dR(r.+k3,m)
            r+=(k1.+2.0*k2.+2.0.*k3.+k4)./6

            #check separation after each dt step
            sep12=sqrt((x1[i]-x2[i])^2+(y1[i]-y2[i])^2+(z1[i]-z2[i])^2)
            sep13=sqrt((x1[i]-x3[i])^2+(y1[i]-y3[i])^2+(z1[i]-z3[i])^2)
            sep23=sqrt((x3[i]-x2[i])^2+(y3[i]-y2[i])^2+(z3[i]-z2[i])^2)

            if sep12<min12 || sep13<min13 || sep23<min23 || sep12>sepStop || sep13>sepStop || sep23>sepStop
                stop=true #stop if collision happens or body is ejected
                t=range(0,stop=currentT,length=i) #t should match pos vectors
                x1=x1[1:i] #don't want trailing zeros
                y1=y1[1:i]
                z1=z1[1:i]
                x2=x2[1:i]
                y2=y2[1:i]
                z2=z2[1:i]
                x3=x3[1:i]
                y3=y3[1:i]
                z3=z3[1:i]
            end
            i+=1
            currentT+=stepSize #next step
        end
    end
    return [x1,y1,z1,x2,y2,z2,x3,y3,z3], t, m, rad
end

function getInteresting3Body(minTime=0) #in years, defaults to 0
    #sometimes random conditions result in a really short animation where things
    #just crash into each other/fly away, so this function throws away those
    yearSec=365*24*3600
    interesting=false
    i=1
    while interesting==false
        plotData,t,m,rad=gen3Body([60,150],600000)
        if (maximum(t)/yearSec)>minTime #only return if simulation runs for longer than minTime
            println(maximum(t)/yearSec) #tell me how many years we are simulating
            open("cron_log.txt","a") do f #for cron logging, a flag = append
                write(f,"$(maximum(t)/yearSec)\n")
            end
            return plotData,t,m,rad
            interesting=true
        elseif i>5000 #computationally expensive so don't want to go forever
            interesting=true #render it anyways I guess because sometimes it's fun?
            println("did not find interesting solution in number of tries allotted, running anyways")
            println(maximum(t)/yearSec) #how many years simulation runs for
            open("cron_log.txt","a") do f #for cron logging
                write(f,"$(maximum(t)/yearSec)\n")
            end
            return plotData,t,m,rad
        end
        i+=1
    end
end

function getLims(pos,padding) #determines plot limits at each frame, padding in units of pos
    x=[pos[1],pos[4],pos[7]]
    xMin=minimum(x)
    xMax=maximum(x)
    dx=xMax-xMin
    y=[pos[2],pos[5],pos[8]]
    yMin=minimum(y)
    yMax=maximum(y)
    dy=yMax-yMin
    z=[pos[3],pos[6],pos[9]]
    zMin=minimum(z)
    zMax=maximum(z)
    dz=zMax-zMin
    dList=[dx,dy,dz]
    if maximum(dList)==dx
        #use x for square
        xlims=[xMin-padding,xMax+padding]
        ylims=[yMin-padding,yMin+dx+padding]
        zlims=[zMin-padding,zMin+dx+padding]
    elseif maximum(dList)==dy
        #use y for square
        xlims=[xMin-padding,xMin+dy+padding]
        ylims=[yMin-padding,yMax+padding]
        zlims=[zMin-padding,zMin+dy+padding]
    else
        #use z for cube
        xlims=[xMin-padding,xMin+dz+padding]
        ylims=[yMin-padding,yMin+dz+padding]
        zlims=[zMin-padding,zMax+padding]
    end
    return xlims,ylims,zlims
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

function makeCircleVals(r,center=[0,0,0])
    #(x,y,z)=(rcos(theta)sin(phi),rsin(theta)sin(phi),rcos(phi))
    xOffset=center[1]
    yOffset=center[2]
    zOffset=center[3]
    xVals=[]
    yVals=[]
    zVals=[]
    for i=0:pi/128:2*pi
        for j=0:pi/64:pi
            x=r*cos(i)*sin(j)+xOffset
            y=r*sin(i)*sin(j)+yOffset
            z=r*cos(j)+zOffset
            push!(xVals,x)
            push!(yVals,y)
            push!(zVals,z)
        end
    end
    return xVals,yVals,zVals
end

plotData,t,m,rad=getInteresting3Body(15)
c=[:DodgerBlue,:Gold,:Tomato] #most massive to least massive, also roughly corresponds to temp
colors=getColors(m,c)
#adding fake stars
numStars=2500
starsX=zeros(numStars)
starsY=zeros(numStars)
starsZ=zeros(numStars)
for i=1:numStars
    num=rand(-200:200,3) #box size is 70 AU but we need some extra padding for movement
    starsX[i]=num[1]
    starsY[i]=num[2]
    starsZ[i]=num[3]
end

#this new way runs significantly faster (~2x improvement over @anim)
#Downside is it spams folder with png images of every frame and must manually compile with ffmpeg
#Comment out and use older way (after this below) if performance/specific formatting is not an issue

plotLoadPath="/home/kirk/Documents/3Body/tmpPlots/"
threeBodyAnim=Animation(plotLoadPath,String[])
for i=1:333:length(t) #this makes animation scale ~1 sec/year with other conditions
    GR.inline("png") #added to eneable cron/jobber compatibility, also this makes frames generate WAY faster? Prior to adding this when run from cron/jobber frames would stop generating at 408 for some reason.
    gr(legendfontcolor = plot_color(:white)) #legendfontcolor=:white plot arg broken right now (at least in this backend)
    print("$(@sprintf("%.2f",i/length(t)*100)) % complete\r") #output percent tracker
    pos=[plotData[1][i],plotData[2][i],plotData[3][i],plotData[4][i],plotData[5][i],plotData[6][i],plotData[7][i],plotData[8][i],plotData[9][i]] #current pos
    limx,limy,limz=getLims(pos./1.5e11,10) #convert to AU, 10 AU padding
    p=plot3d(plotData[1][1:33:i]./1.5e11,plotData[2][1:33:i]./1.5e11,plotData[3][1:33:i]./1.5e11,label="",linecolor=colors[1],linealpha=max.((1:33:i) .+ 10000 .- i,2500)/10000) #plot orbits up to i
    p=plot3d!(plotData[4][1:33:i]./1.5e11,plotData[5][1:33:i]./1.5e11,plotData[6][1:33:i]./1.5e11,label="",linecolor=colors[2],linealpha=max.((1:33:i) .+ 10000 .- i,2500)/10000) #linealpha argument causes lines to decay
    p=plot3d!(plotData[7][1:33:i]./1.5e11,plotData[8][1:33:i]./1.5e11,plotData[9][1:33:i]./1.5e11,label="",linecolor=colors[3],linealpha=max.((1:33:i) .+ 10000 .- i,2500)/10000) #example: alpha=max.((1:i) .+ 100 .- i,0) causes only last 100 to be visible
    p=scatter3d!(starsX,starsY,starsZ,markercolor=:white,markersize=:1,label="") #fake background stars
    star1=makeCircleVals(rad[1],[plotData[1][i],plotData[2][i],plotData[3][i]]) #generate spheres with appropriate sizes for each star
    star2=makeCircleVals(rad[2],[plotData[4][i],plotData[5][i],plotData[6][i]]) #at current positions
    star3=makeCircleVals(rad[3],[plotData[7][i],plotData[8][i],plotData[9][i]])
    p=plot3d!(star1[1]./1.5e11,star1[2]./1.5e11,star1[3]./1.5e11,label="$(@sprintf("%.1f", m[1]./2e30))",color=colors[1],fill=true) #plot star circles with labels
    p=plot3d!(star2[1]./1.5e11,star2[2]./1.5e11,star2[3]./1.5e11,label="$(@sprintf("%.1f", m[2]./2e30))",color=colors[2],fill=true)
    p=plot3d!(star3[1]./1.5e11,star3[2]./1.5e11,star3[3]./1.5e11,label="$(@sprintf("%.1f", m[3]./2e30))",color=colors[3],fill=true)
    p=plot3d!(background_color=:black,background_color_legend=:transparent,foreground_color_legend=:transparent,
        background_color_outside=:white,aspect_ratio=:equal,legendtitlefontcolor=:white) #formatting for plot frame
    p=plot3d!(title="Random Three-Body Problem\nt: $(@sprintf("%0.2f",t[i]/365/24/3600)) years after start",
        legend=:best,xaxis=("x: AU",(limx[1],limx[2]),font(9,"Courier")),yaxis=("y: AU",(limy[1],limy[2]),font(9,"Courier")),zaxis=("z: AU",(limz[1],limz[2]),font(9,"Courier")),
        gridalpha=0.5,gridcolor=:white,titlefont=font(14,"Courier"),size=(720,721),legendfontsize=8,legendtitle="Mass (in solar masses)",legendtitlefontsize=8) #add in axes/title/legend with formatting
    frame(threeBodyAnim,p) #generate the frame
    closeall() #close plots
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
