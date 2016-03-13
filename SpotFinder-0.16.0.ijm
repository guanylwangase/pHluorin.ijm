////////////////////////////////////////////////////////////////////////////////////////////
////////                          Initialisation                             ///////////////
////////////////////////////////////////////////////////////////////////////////////////////
directory=getDirectory("Choose a Directory");
list=getFileList(directory);
batchlist=newArray();
for (i=0;i<list.length;i++){
	if(endsWith(list[i], '.tif')==1 || endsWith(list[i], '.tiff')==1){
	batchlist=Array.concat(batchlist,list[i]);}
}
logimgname=newArray();
logslices=newArray();
logcount=newArray();
batchcount=0;

setBatchMode(true);
for(imgi=0;imgi<batchlist.length;imgi++){
///////////////////START OF ANALYSIS/////////////////////////
run("Close All");
batchcount=batchcount+1;
open(directory+batchlist[imgi]);

ID = getImageID();
img=getTitle();
path=getInfo("image.directory");
getDimensions(width, height, channels, slices, frames);

run("Select None");
run("Clear Results"); 
roiManager("reset");
/////////////user parameters
//zone1=cap @begin zone2=cap @follow zone3=cap @end
zone1=0;
zone2=10;
zone3=1;

spotsprctile=0.9996;
//blackholeri
bhprctile=0.9992;
distmax1=10;
//whiteholei
whprctile=0.92;
distmax3=8;
//Hawking radiation ri+1
hrprctile=0.9992;
distmax4=10;
distmin4=5;

r2min=0.8;
taumin=0.5;

FWHMmin=2.5;
FWHMmax=10;

//amplitude limit
ampminlim=0.98;

//cor=correction of bleaching/variation
img2cor=img;
iscorrection=1;

//img2measure=img;
imgname="FOREGROUND";

//img2process="FOREGROUND-meanmin";
img2process=imgname+"-fill";

img2m4fit=imgname+"-blur";
img2m4fwhm=imgname+"-blur";
outputimg=imgname;


//tail=2;

islog=1;
/////////////internal parameters
nSlicesR=slices-1;
nSlicesM=nSlicesR-zone2-zone3;

setOption("BlackBackground", true)
;
setForegroundColor(255,255,255)
;
setBackgroundColor(0,0,0)
;
////////////////////////////////////////////////////////////////////////////////////////////
////////                              PROCESSING                             ///////////////
////////////////////////////////////////////////////////////////////////////////////////////
//selectWindow(img);
//run("Mean...", "radius=1 stack");


//////////////////////correct fluorescence fluctuation
///
if (iscorrection==1){
	corprctint(img2cor,5);
}



/////////////////// substract background
hullbk(img);
rename(imgname);

run("Subtract Background...", "rolling=50 stack");


run("Duplicate...", "title="+imgname+"-fill duplicate range=1-"+nSlices);
run("Mean...", "radius=25 stack");
for (i=1;i<nSlices+1;i++){
	for(x=0;x<width;x++){
		for(y=0;y<height;y++){
			selectWindow(imgname);
			setSlice(i);
			vo=getPixel(x,y);
			selectWindow(imgname+"-fill");
			setSlice(i);
			vb=getPixel(x,y);			
			if(vb<vo){
				setPixel(x,y,vo);
			}			
		}
	}
}


run("Gaussian Blur...", "sigma=1 stack");

///////////////////Substact each slice 
for (i=1;i<nSlicesR;i++){
	selectWindow(img2process);
	setSlice(i);
	run("Duplicate...", "title=" + i);
	selectWindow(img2process);
	setSlice(i+1);
	run("Duplicate...", "title=" + (i+1));
	imageCalculator("Subtract create 32-bit", ""+ (i+1) +"",""+ i +"");

	selectWindow(i);
	close();
	selectWindow(i+1);
	close();

	if(i==1){newImage("Result1", "32-bit", width, height, nSlicesR);}
;
	
	selectWindow("Result of " + (i+1));
	run("Select All");
	run("Copy");
	close();
	selectWindow("Result1");
	setSlice(i);
	run("Paste");
	run("Select None");
	
}
//un("Enhance Contrast", "saturated=0.4");
//run("Bandpass Filter...", "filter_large=10 filter_small=2 suppress=None tolerance=0 process");
//
run("Median 3D...", "x=1 y=1 z=1");
run("Median...", "radius=1 stack");
selectWindow("Result1");
run("Duplicate...", "title=Result1-dup duplicate range=1-"+nSlicesR);
selectWindow("Result1-dup");
run("Multiply...", "value=-1 stack");



newImage("SpotMask","8-bit Black",width,height,nSlicesM);

selectWindow("Result1");


bhxlist=newArray(0);bhylist=newArray(0);bhslist=newArray(0);
whxlist=newArray(0);whylist=newArray(0);whslist=newArray(0);
hrxlist=newArray(0);hrylist=newArray(0);hrslist=newArray(0);

for (m=1;m<nSlicesM+1;m++){
	//////////////////identify spots
	selectWindow("Result1");
	setSlice(m);
	prctile1=getpercentile("Result1",spotsprctile);
	noiselevel=prctile1;
	//getStatistics(area, mean, min, max);
	//noiselevel=(max+mean)/2;
	run("Find Maxima...", "noise="+noiselevel+" output=[Point Selection]");
	
	newImage("Mask1", "8-bit Black", width, height, 1);
	selectWindow("Mask1");
	run("Restore Selection");
	run("Draw");
	run("Select None");
	
	selectWindow("Result1");
	run("Find Maxima...", "noise="+noiselevel+" output=List");
	arrayx1=newArray(nResults);
	arrayy1=newArray(nResults);
		for (i=0;i<nResults;i++){
			arrayx1[i]=getResult("X",i);
			arrayy1[i]=getResult("Y",i);}
	run("Clear Results");
	
	///////////////blackhole identify spots moving in///

	selectWindow("Result1-dup");
	setSlice(m);
	prctile2=getpercentile("Result1-dup",bhprctile);
	noiselevel=prctile2;
	//getStatistics(area, mean, min, max);
	//noiselevel=(max+mean)/2;
	run("Find Maxima...", "noise="+noiselevel+" output=[Point Selection]");
	newImage("Mask2", "8-bit Black", width, height, 1);
	selectWindow("Mask2");
	run("Restore Selection");
	run("Draw");
	run("Select None");
	
	run("Find Maxima...", "noise="+noiselevel+" output=List");
	arrayx2=newArray(nResults);
	arrayy2=newArray(nResults);
		for (i=0;i<nResults;i++){
			arrayx2[i]=getResult("X",i);
			arrayy2[i]=getResult("Y",i);}
	run("Clear Results");
	

	///////////////whitehole identify spots moving along z///

	selectWindow(img2process);
	setSlice(m);
	prctile3=getpercentile(img2process,whprctile);
	noiselevel=prctile3;
	run("Find Maxima...", "noise="+noiselevel+" output=[Point Selection]");
	newImage("Mask3", "8-bit Black", width, height, 1);
	selectWindow("Mask3");
	run("Restore Selection");
	run("Draw");
	run("Select None");
	
	run("Find Maxima...", "noise="+noiselevel+" output=List");
	arrayx3=newArray(nResults);
	arrayy3=newArray(nResults);
		for (i=0;i<nResults;i++){
			arrayx3[i]=getResult("X",i);
			arrayy3[i]=getResult("Y",i);}
	run("Clear Results");
	//selectWindow("substack");close();
	//selectWindow("AVG_substack");close();
	selectWindow(img2process);run("Select None");

	///////////////Hawking radiation identify spots moving out///

	selectWindow("Result1");
	setSlice(m+1);
	prctile4=getpercentile("Result1",hrprctile);
	noiselevel=prctile4;
	run("Find Maxima...", "noise="+noiselevel+" output=[Point Selection]");	
	newImage("Mask4", "8-bit Black", width, height, 1);
	selectWindow("Mask4");
	run("Restore Selection");
	run("Draw");
	run("Select None");
	
	selectWindow("Result1");
	run("Find Maxima...", "noise="+noiselevel+" output=List");
	arrayx4=newArray(nResults);
	arrayy4=newArray(nResults);
		for (i=0;i<nResults;i++){
			arrayx4[i]=getResult("X",i);
			arrayy4[i]=getResult("Y",i);}
	run("Clear Results");


	
	////////////////Remove the spot closest to a blackhole
	
distance1=newArray(arrayx1.length);
	for (i=0;i<arrayx2.length;i++){
		for(j=0;j<arrayx1.length;j++){
			distance1[j]=sqrt((arrayx2[i]-arrayx1[j])*(arrayx2[i]-arrayx1[j])+(arrayy2[i]-arrayy1[j])*(arrayy2[i]-arrayy1[j]));}
		dr=Array.rankPositions(distance1);
		k=dr[0];
		if (distance1[k]<=distmax1){
			selectWindow("Mask1");
			setPixel(arrayx1[k],arrayy1[k],16);
			bhxlist=Array.concat(bhxlist,arrayx1[k]);bhylist=Array.concat(bhylist,arrayy1[k]);bhslist=Array.concat(bhslist,m+1);
}}


	distance3=newArray(arrayx1.length);
	for (i=0;i<arrayx3.length;i++){
		for(j=0;j<arrayx1.length;j++){
			distance3[j]=sqrt((arrayx3[i]-arrayx1[j])*(arrayx3[i]-arrayx1[j])+(arrayy3[i]-arrayy1[j])*(arrayy3[i]-arrayy1[j]));}
		dr=Array.rankPositions(distance3);
		k=dr[0];
		if (distance3[k]<=distmax3){
			selectWindow("Mask1");
			setPixel(arrayx1[k],arrayy1[k],16);
			whxlist=Array.concat(whxlist,arrayx1[k]);whylist=Array.concat(whylist,arrayy1[k]);whslist=Array.concat(whslist,m+1);}}

	distance4=newArray(arrayx1.length);
	for (i=0;i<arrayx4.length;i++){
		for(j=0;j<arrayx1.length;j++){
			distance4[j]=sqrt((arrayx4[i]-arrayx1[j])*(arrayx4[i]-arrayx1[j])+(arrayy4[i]-arrayy1[j])*(arrayy4[i]-arrayy1[j]));}
		dr=Array.rankPositions(distance4);
		k=dr[0];
		//print(i,j,distance2[k]);
		if (distance4[k]<=distmax4 && distance4[k]>distmin4){
			selectWindow("Mask1");
			setPixel(arrayx1[k],arrayy1[k],16);
			hrxlist=Array.concat(hrxlist,arrayx1[k]);hrylist=Array.concat(hrylist,arrayy1[k]);hrslist=Array.concat(hrslist,m+1);}}
	
	////////////////////////output
	selectWindow("Mask1");
	run("Select All");
	run("Copy");
	selectWindow("SpotMask");
	setSlice(m);
	run("Paste");
	run("Select None");
	
	
	
	///////////////////////////clean up
	selectWindow("Mask1");
close();
	selectWindow("Mask2");
close();
	selectWindow("Mask3");close();
	selectWindow("Mask4");close();
		
}

if(islog==1){
	run("Clear Results");
	for(i=0;i<bhxlist.length;i++){
		setResult("S-BH", i, bhslist[i]);
		setResult("X-BH", i, bhxlist[i]);
		setResult("Y-BH", i, bhylist[i]);
	}	
	for(i=0;i<whxlist.length;i++){
		setResult("S-WH", i, whslist[i]);
		setResult("X-WH", i, whxlist[i]);
		setResult("Y-WH", i, whylist[i]);
	}
	for(i=0;i<hrxlist.length;i++){
		setResult("S-HR", i, hrslist[i]);
		setResult("X-HR", i, hrxlist[i]);
		setResult("Y-HR", i, hrylist[i]);
	}
	
	saveAs("Results", path+img+"-dex.txt");
	run("Clear Results");

}



/////////////////////////////////////////////////////////////////////////////////////

selectWindow("Result1");close();
selectWindow("Result1-dup");close();
selectWindow("SpotMask");
//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
//selectWindow(img);
//run("Subtract Background...", "rolling=10 stack");

newImage("SpotMask1", "8-bit Black", width, height, nSlicesM);
for (i=0;i<nSlicesM;i++){
	selectWindow("SpotMask");
	run("Select None");
	setSlice(i+1);
	run("Find Maxima...", "noise=254 output=[Point Selection]");
	selectWindow("SpotMask1");
	setSlice(i+1);
	setColor(255);
	run("Restore Selection");
	run("Draw", "slice");
	run("Select None");
}
roiManager("reset");
selectWindow("SpotMask1");
run("Analyze Particles...", "size=0-Infinity circularity=0.00-1.00 show=Nothing add stack");

nspot=roiManager("count");
roiManager("Show None");


///some preparations for data output
sliceinlist=newArray(0);
xinlist=newArray(0);
yinlist=newArray(0);
r2inlist=newArray(0);
tauinlist=newArray(0);
FWHMinlist=newArray(0);
amp2inlist=newArray(0);
muinlist=newArray(0);

sliceexlist=newArray(0);
xexlist=newArray(0);
yexlist=newArray(0);
r2exlist=newArray(0);
tauexlist=newArray(0);
FWHMexlist=newArray(0);
ampexlist=newArray(0);
amp2exlist=newArray(0);
ampminexlist=newArray(0);
muexlist=newArray(0);

selectWindow(imgname);
run("Duplicate...", "title="+imgname+"-blur duplicate range=1-"+nSlices);
selectWindow(imgname+"-blur");
//run("Median 3D...", "x=1 y=1 z=1");
//run("Mean...", "radius=1 stack");
run("Gaussian Blur...", "sigma=1 stack");
selectWindow(imgname);

for (i=0;i<nspot;i++){
	//false=0, yes=1
	isincluded=1;
	showProgress(i/nspot);
	selectWindow("SpotMask1");
	roiManager("select",i);
	s=getSliceNumber();
	Roi.getCoordinates(xpoints, ypoints);
	x=xpoints[0]-1;y=ypoints[0]-1;
	
	selectWindow(img2m4fit);
	setSlice(s+1);
	//optimize x,y coordinates;
	dm=3;
	run("Select None");
	makeOval(x-dm-1, y-dm-1, dm*2+1,dm*2+1);
	run("Clear Results");
	run("Set Measurements...", "  center redirect=None decimal=3");
	run("Measure");
	run("Select None");
	xm=floor(getResult("XM",0));
	ym=floor(getResult("YM",0));
	
	newImage("SpotMask2", "8-bit Black", width, height,1);
	setPixel(xm,ym,255);
	run("Maximum...", "radius=0.5");
	run("Create Selection");
	run("Make Inverse");
	run("Clear");
	close();
	
	selectWindow(img2m4fit);
	setSlice(s);
	run("Restore Selection");
	getStatistics(area,mean,min,max);
	bk=mean;
	fluo=newArray(zone2);
	fluo2=newArray(zone2);
	fluo3=newArray(zone2);
	
	for(j=0;j<zone2;j++){
		selectWindow(img2m4fit);
		setSlice(s+j+1);
		//run("Restore Selection");
		getStatistics(area,mean,min,max);
		fluo[j]=mean-bk;}

	while(fluo[0]<=fluo[1] && fluo.length>2){
		for(j=0;j<fluo.length-1;j++){
			fluo[j]=fluo[j+1];
		}
		fluo=Array.trim(fluo,fluo.length-1);
	}
	
	xaxe=newArray(fluo.length);
	for(j=0;j<fluo.length;j++){xaxe[j]=j+1;}	
	for(j=0;j<fluo.length-1;j++){fluo2[j]=(fluo[j]+fluo[j+1])/2;}
	for(j=1;j<fluo.length-1;j++){fluo3[j]=(fluo[j-1]+fluo[j+1])/4+fluo[j]/2;}
	fluo3[0]=fluo[0];fluo3[fluo.length-1]=fluo[fluo.length-1];
	

	
	fluo4=newArray(fluo.length);
	fluo4=smoothcurve(fluo,2);

	Fit.doFit("Exponential", xaxe, fluo4);
	r2=Fit.rSquared;
	a=Fit.p(0);
	b=Fit.p(1)*(-1);
	tau=1/b;

	selectWindow(img2m4fit);
	setSlice(s);
	run("Select None");
	setAutoThreshold("Default dark");
	getThreshold(lower, upper);
	resetThreshold();

	//ampmin=getpercentile(img2m4fit,0.99);
	selectWindow(img2m4fit);
	ampmin=getpercentile(img2m4fit,ampminlim);
	
	
	
	////R^2
	if (r2<r2min){
	selectWindow("SpotMask");
	run("Select None");
	roiManager("select",i);
	setPixel(x,y,48);
	isincluded=0;}

	////Amplitude
	if (a<ampmin){
	selectWindow("SpotMask");
	run("Select None");
	roiManager("select",i);
	setPixel(x,y,64);
	isincluded=0;}


	////half lift tau=1/b second
	if (tau<taumin){
	selectWindow("SpotMask");
	run("Select None");
	roiManager("select",i);
	setPixel(x,y,80);
	isincluded=0;}

	//Mu=tau*ampmin
	mu=fluo[0]*tau;
	mumin=ampmin*1;
	if (mu<mumin){
	selectWindow("SpotMask");
	run("Select None");
	roiManager("select",i);
	setPixel(x,y,112);
	isincluded=0;}

	////FWHM
	selectWindow(img2m4fwhm);
	setSlice(s+1);

	//optimize x,y coordinates;
	//dm=3;
	//run("Select None");
	//makeOval(x-dm-1, y-dm-1, dm*2+1,dm*2+1);
	//run("Clear Results");
	//run("Set Measurements...", "  center redirect=None decimal=3");
	//run("Measure");
	//run("Select None");
	//xm=floor(getResult("XM",0));
	//ym=floor(getResult("YM",0));
	
	
	////optiFWHM(x,y,radmax,radmin,r2limit,mode of selection)
	//mode="min","r2"
	//oFWHM=optiFWHM(xm,ym,7,2,0.9,"min");
	//FWHM=oFWHM;
	
	//getFWHM(x,y,wid,radmax,radmin,r2lim,mode)
	FWHM=getFWHM(x,y,4,10,5,0.9,"min");

	if (FWHM<FWHMmin||FWHM>FWHMmax){
	selectWindow("SpotMask");
	run("Select None");
	roiManager("select",i);
	setPixel(x,y,96);
	isincluded=0;}

	///creat result list
	
	if (isincluded==1){
		sliceinlist=Array.concat(sliceinlist,s+1);
		xinlist=Array.concat(xinlist,x);
		yinlist=Array.concat(yinlist,y);
		r2inlist=Array.concat(r2inlist,r2);
		tauinlist=Array.concat(tauinlist,tau);
		FWHMinlist=Array.concat(FWHMinlist,FWHM);
		amp2inlist=Array.concat(amp2inlist,fluo4[0]);
		muinlist=Array.concat(muinlist,mu);}
	else{
		sliceexlist=Array.concat(sliceexlist,s+1);
		xexlist=Array.concat(xexlist,x);
		yexlist=Array.concat(yexlist,y);
		r2exlist=Array.concat(r2exlist,r2);
		tauexlist=Array.concat(tauexlist,tau);
		FWHMexlist=Array.concat(FWHMexlist,FWHM);
		ampexlist=Array.concat(ampexlist,a);
		amp2exlist=Array.concat(amp2exlist,fluo4[0]);
		ampminexlist=Array.concat(ampminexlist,ampmin);
		muexlist=Array.concat(muexlist,mu);}
	
}		

/////write results to text file table
if(islog==1){
	nresults=sliceinlist.length;
	run("Clear Results");
	for(i=0;i<nresults;i++){
		setResult("Slice", i, sliceinlist[i]);
		setResult("X", i, xinlist[i]);
		setResult("Y", i, yinlist[i]);
		setResult("R2", i, r2inlist[i]);
		setResult("Tau", i, tauinlist[i]);
		setResult("FWHM", i, FWHMinlist[i]);
		setResult("Amplitide2", i, amp2inlist[i]);
		setResult("Mu",i,muinlist[i]);
	}	
	saveAs("Results", path+img+"-results.txt");
	run("Clear Results");
	
	nexcluded=sliceexlist.length;	
	for(i=0;i<nexcluded;i++){
		setResult("Slice", i, sliceexlist[i]);
		setResult("X", i, xexlist[i]);
		setResult("Y", i, yexlist[i]);
		setResult("R2", i, r2exlist[i]);
		setResult("Tau", i, tauexlist[i]);
		setResult("FWHM", i, FWHMexlist[i]);
		setResult("Amplitide", i, ampexlist[i]);
		setResult("Amplitide_real", i, amp2exlist[i]);
		setResult("Amplitide_minlim", i, ampminexlist[i]);
		setResult("Mu",i,muexlist[i]);
	}	
	saveAs("Results", path+img+"-excluded.txt");
	run("Clear Results");

}


selectWindow("SpotMask");
run("Select None");
run("Duplicate...", "title=SpotMaskShow duplicate range=1-"+nSlicesM);
run("Maximum...", "radius=1.5 stack");


setLineWidth(2);
d=10;

for (i=0;i<nSlicesM;i++){
	selectWindow("SpotMask");
	setSlice(i+1);
	run("Find Maxima...", "noise=254 output=List");
	//selectWindow(title);
	selectWindow(outputimg);
	setSlice(i+2);	
	for (j=0;j<nResults;j++){
		x=getResult("X",j);
		y=getResult("Y",j);
		selectWindow("SpotMask");
		if (getPixel(x,y)==255){
		selectWindow(outputimg);
		getStatistics(area, mean, min, max);
		setColor(max);	
		drawOval(x-d, y-d, 2*d+1, 2*d+1);
		}
	}
		
	run("Clear Results");
}

selectWindow(outputimg);
//rename(img+"-result");
setSlice(5);
run("Enhance Contrast...", "saturated=0 process_all use");
setSlice(1);
saveAs("Tiff",path+img+"-result.tif");

//selectWindow("SpotMask");


logimgname=Array.concat(logimgname,img);
logslices=Array.concat(logslices,nSlicesM);
logcount=Array.concat(logcount,nresults);

for(i=0;i<batchcount;i++){
	setResult("Image", i, logimgname[i]);
	setResult("Slices", i, logslices[i]);
	setResult("Events", i, logcount[i]);
	}	
saveAs("Results", path+"log.txt");
run("Clear Results");

run("Close All");
//free up memery space
call("java.lang.System.gc"); 

}//the end of batch process

setBatchMode(false);
//0
//1
//2
//3
//4
//5
//6
//7
//8
//9
//10
//11
//12
//13
//14
//15
//16
//17
//18
//19
////////////////////////////////////////////////////////////////////////////////////////////
////////                          FUNCTIONS                                  ///////////////
////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////
/////       GET PERCENTILE   //////
///////////////////////////////////
function getpercentile(imagetitle,percentile){
	selectWindow(imagetitle);
	nBins=256;
	getStatistics(area, mean, min, max, std);
	getHistogram(values, counts, 256); 
	
	//create a cumulative histogram 
	cumHist=newArray(nBins); 
	cumHist[0]=counts[0]; 
	for (i=1; i<nBins; i++){ cumHist[i]=counts[i]+cumHist[i-1]; } 
	
	//normalize the cumulative histogram 
	normCumHist = newArray(nBins); 
	for (i=0; i<nBins; i++){ normCumHist[i]=cumHist[i]/cumHist[nBins-1]; } 
	
	// find the percentile
	i=0; 
	while (normCumHist[i]<percentile) {i=i+1;}
	prctilevalue=values[i];
	
	return prctilevalue;
}
/////End of function

///////////////////////////////////////////////////////
/////    PERCENTILE BASED INTENSITY CORRECTION   //////
///////////////////////////////////////////////////////

function getprctintmean(imagetitle,lowpercentile,highpercentile,nBins){
	selectWindow(imagetitle);
	//nBins=256;
	getStatistics(area, mean, min, max, std);
	getHistogram(values, counts, nBins); 
	
	//create a cumulative histogram 
	cumHist=newArray(nBins); 
	cumHist[0]=counts[0]; 
	for (i=1; i<nBins;i++){ cumHist[i]=counts[i]+cumHist[i-1]; } 
	
	//normalize the cumulative histogram 
	normCumHist = newArray(nBins); 
	for (i=0; i<nBins;i++){ normCumHist[i]=cumHist[i]/cumHist[nBins-1]; } 
	
	// find the percentile
	i=0; 
	while (normCumHist[i]<lowpercentile) {i=i+1;}
	j=0;
	while (normCumHist[j]<highpercentile) {j=j+1;}

	//find the mean of selected interval
	sumvalue=0;sumcount=0;
	for (l=i;l<j+1;l++){
		sumvalue=sumvalue+values[l]*counts[l];
		sumcount=sumcount+counts[l];
	}
	mean=sumvalue/sumcount;

	return mean;
}


/////////////////////////////////////////////////////
/////     Calculate  FWHM    Method1:Single X Y//////
/////////////////////////////////////////////////////
/////Calculate FWHM from given coordinate
/////x y coordinates, dx dy line half length, one should be 0 
function findFWHM(x,y,dx,dy){
	makeLine(x-dx, y-dy, x+dx, y+dy);
	p=getProfile();
	run("Select None");
	xaxe=newArray(p.length);
	for(l=0;l<p.length;l++){xaxe[l]=l;};
	Fit.doFit("Gaussian", xaxe, p);
	sigma=Fit.p(3);
	FWHMvalue=sigma*2.355;
	r2=Fit.rSquared;
	
	results=newArray(FWHMvalue,r2,p.length);
	return results;}
	
function optiFWHM(x,y,radmax,radmin,r2lim,mode){
	lenrad=radmax-radmin+1;
	FWHMv=newArray(lenrad);
	FWHMr2=newArray(lenrad);
	FWHMfd=newArray(lenrad);

	rad0=radmax;
	for(i=0;i<lenrad;i++){
		rad=rad0-i;
		rFWHM=findFWHM(x,y,rad,0);
		if (rFWHM[1]>r2lim){
		FWHMv[i]=rFWHM[0];
		FWHMr2[i]=rFWHM[1];
		FWHMfd[i]=rFWHM[2];}
		else{
		FWHMv[i]=999;
		FWHMr2[i]=0;
		FWHMfd[i]=rFWHM[2];
		}
	}
	rankv=Array.rankPositions(FWHMv);
	rankr2=Array.rankPositions(FWHMr2);
	if (mode=="min"){
		posx=rankv[0];}
	else if(mode=="r2"){
		posx=rankr2[lenrad-1];
	}
	
	FWHMvx=FWHMv[posx];
	FWHMr2x=FWHMr2[posx];
	FWHMfdx=FWHMfd[posx];
	

	FWHMv=newArray(lenrad);
	FWHMr2=newArray(lenrad);
	FWHMd=newArray(lenrad);
	for(i=0;i<lenrad;i++){
		rad=rad0-i;
		rFWHM=findFWHM(x,y,rad,0);
		if (rFWHM[1]>r2lim){
		FWHMv[i]=rFWHM[0];
		FWHMr2[i]=rFWHM[1];
		FWHMfd[i]=rFWHM[2];}
		else{
		FWHMv[i]=999;
		FWHMr2[i]=0;
		FWHMfd[i]=rFWHM[2];
		}
	}
	rankv=Array.rankPositions(FWHMv);
	rankr2=Array.rankPositions(FWHMr2);
	if (mode=="min"){
		posy=rankv[0];}
	else if(mode=="r2"){
		posy=rankr2[lenrad-1];
	}
	FWHMvy=FWHMv[posy];
	FWHMr2y=FWHMr2[posy];
	FWHMfdy=FWHMfd[posy];
	
	//print(FWHMr2x,FWHMfdx,FWHMr2y,FWHMfdy);
	FWHM=sqrt(FWHMvx*FWHMvy);

	return FWHM;	
}
/////////////////////////////////////////////////////
/////     Calculate  FWHM    Method2:mean aera//////
/////////////////////////////////////////////////////
function getFWHM(x,y,wid,radmax,radmin,r2lim,mode){
	//construct x y data set to fit
	xvalues=newArray(2*radmax+1);yvalues=newArray(2*radmax+1);
	for (i=0;i<xvalues.length;i++){
		xjvalue=0;yjvalue=0;
		for (j=0;j<2*wid+1;j++){
			xjvalue=xjvalue+getPixel(x-radmax+i,y-wid+j);
			yjvalue=yjvalue+getPixel(x-wid+j,y-radmax+i);
		}
		xvalues[i]=xjvalue/(2*wid+1);
		yvalues[i]=yjvalue/(2*wid+1);			
	}

	//fit
	len=(radmax-radmin+1)*2;
	xFWHM=newArray(len);yFWHM=newArray(len);
	xr2=newArray(len);yr2=newArray(len);
	
	for (i=radmin;i<=radmax;i++){
		//construct x y data set to fit
		xfitvalues=newArray(2*i+1);
		yfitvalues=newArray(2*i+1);
		for(j=0;j<2*i+1;j++){
			xfitvalues[j]=xvalues[radmax-i+j];
			yfitvalues[j]=yvalues[radmax-i+j];
		}
	axe=newArray(2*i+1);
	for(l=0;l<axe.length;l++){axe[l]=l+1;};

	// fit x	
	Fit.doFit("Gaussian", axe, xfitvalues);
	sigma=Fit.p(3);
	xFWHM[i-radmin]=sigma*2.355;
	xr2[i-radmin]=Fit.rSquared;

	// fit y	
	Fit.doFit("Gaussian", axe, yfitvalues);
	sigma=Fit.p(3);
	yFWHM[i-radmin]=sigma*2.355;
	yr2[i-radmin]=Fit.rSquared;
	}
	
	//apply r2lim
	for (i=0;i<len;i++){
		if(xFWHM[i]<r2lim){xFWHM[i]=999;xr2[i]=0;}
		if(yFWHM[i]<r2lim){yFWHM[i]=999;yr2[i]=0;}
	}

	//find best values
	rankxFWHM=Array.rankPositions(xFWHM);
	rankyFWHM=Array.rankPositions(yFWHM);
	rankxr2=Array.rankPositions(xr2);
	rankyr2=Array.rankPositions(yr2);
	
	if (mode=="min"){
		nx=rankxFWHM[0];
		ny=rankyFWHM[0];
		}
	else if(mode=="r2"){
		nx=rankxFWHM[len-1];
		ny=rankyFWHM[len-1];	
	}

	xvalue=xFWHM[nx];
	yvalue=yFWHM[ny];
	FWHM=sqrt(xvalue*yvalue);

	return FWHM;	
}
//////////////////////////////////////////////////
/////     Convex hull background remover    //////
//////////////////////////////////////////////////
function hullbk(imagetitle){
selectWindow(imagetitle);
img=getTitle();
getDimensions(width, height, channels, slices, frames);
run("Duplicate...", "title=HULL duplicate range=1-"+nSlices);
run("Duplicate...", "title=FOREGROUND duplicate range=1-"+nSlices);

for (x=0;x<width;x++){
	for(y=0;y<height;y++){

showProgress(x/width);

////enter x,y loop
//get intensity of each pixel
int=newArray(slices);
hullx=newArray(0);
hully=newArray(0);

selectWindow(img);
for(s=0;s<slices;s++){
	setZCoordinate(s);
	int[s]=getPixel(x,y);}

s0=0;
hullx=Array.concat(hullx,0);
hully=Array.concat(hully,int[0]);

while(s0<slices-1){
dint=newArray(slices-1-s0);
for(s=s0+1;s<slices;s++){
	dint[s-s0-1]=(int[s]-int[s0])/(s-s0);}
	
dintr=Array.rankPositions(dint);
k=dintr[0];
s0=k+s0+1;

hullx=Array.concat(hullx,s0);
hully=Array.concat(hully,int[s0]);
}
	

//interpolation
selectWindow("HULL");
setZCoordinate(0);;
setPixel(x,y,hully[0]);

selectWindow("FOREGROUND");
setZCoordinate(0);;
setPixel(x,y,int[0]-hully[0]);

for(i=1;i<hullx.length;i++){
	for(j=hullx[i-1];j<=hullx[i];j++){
		selectWindow("HULL");
		setZCoordinate(j);
		bk=hully[i-1]+(hully[i]-hully[i-1])*(j-hullx[i-1])/(hullx[i]-hullx[i-1]);
		setPixel(x,y,bk);

		selectWindow("FOREGROUND");
		setZCoordinate(j);
		fg=int[j]-bk;
		setPixel(x,y,fg);
	}
}

selectWindow("HULL");
selectWindow("FOREGROUND");
//end of x ,y loop		
}}

}

//////////////////////////////////////////////////
/////     correct fluorescence fluctuation   //////
//////////////////////////////////////////////////
//corbaseslices=radius
function corprctint(image2cor,corbaseslices){
selectWindow(image2cor);
prctintmean=newArray(nSlices);
for (i=1;i<nSlices+1;i++){
	selectWindow(image2cor);
	setSlice(i);
	prctintmean[i-1]=getprctintmean(image2cor,0.4,0.95,256);
}

///part1
for (i=1;i<=corbaseslices+1;i++){
	selectWindow(image2cor);
	setSlice(i);
	cummean=0;
	for(j=1;j<corbaseslices*2+1;j++){
		cummean=cummean+prctintmean[j-1];
	}
	cormean=cummean/corbaseslices/2;
	corvalue=cormean/prctintmean[i-1];
	run("Multiply...", "value="+corvalue+" slice");
}

///part2
for (i=1+corbaseslices;i<nSlices+1-corbaseslices;i++){
	selectWindow(image2cor);
	setSlice(i);
	cummean=0;
	for(j=1;j<corbaseslices+1;j++){
		cummean=cummean+prctintmean[i-j-1];
		cummean=cummean+prctintmean[i+j-1];
	}
	cormean=cummean/corbaseslices/2;
	corvalue=cormean/prctintmean[i-1];
	run("Multiply...", "value="+corvalue+" slice");}
///part3
for (i=nSlices+1-corbaseslices;i<nSlices+1;i++){
	selectWindow(image2cor);
	setSlice(i);
	cummean=0;
	for(j=1;j<corbaseslices*2+1;j++){
		cummean=cummean+prctintmean[nSlices-j];
	}
	cormean=cummean/corbaseslices/2;
	corvalue=cormean/prctintmean[i-1];
	run("Multiply...", "value="+corvalue+" slice");
}
	
}


//////////////////////////////////////////////////
/////             Curve smoothing          //////
//////////////////////////////////////////////////
///span = radius of averaging
function smoothcurve(curve,span){
l=curve.length;
if (l>=3){
smoothed=newArray(l);
sum=0;
smoothed[0]=curve[0];
for (i=2;i<span+1;i++){
	k=0;
	for(j=1;j<i;j++){
		sum=sum+curve[i-j-1]+curve[i+j-1];
		k=k+1;}
	sum=sum+curve[i-1];
	smoothed[i-1]=sum/(2*k+1);
	sum=0;
}	
	
for (i=span+1;i<l-span+1;i++){
	for(j=1;j<span+1;j++){
		sum=sum+curve[i-j-1]+curve[i+j-1];
		}
	sum=sum+curve[i-1];
	smoothed[i-1]=sum/(2*span+1);
	sum=0;
}

for (i=l-span+1;i<l+1;i++){
	k=0;
	for(j=1;j<l-i+1;j++){
		sum=sum+curve[i-j-1]+curve[i+j-1];
		k=k+1;}
	sum=sum+curve[i-1];
	smoothed[i-1]=sum/(2*k+1);
	sum=0;
}
smoothed[l-1]=curve[l-1];
}

else{
	smoothed=newArray(l);
	for(i=0;i<l;i++){smoothed[i]=fluo[i];}
	}

return smoothed;
}


////////////////////////////////////////////////////////////////////////////////////////////
