% Clear any existing state
clear all;
clc;
clf;
tic

% Configuration section
DATA_FOLDER = 'data10/';
ENABLE_TOOLBOX = 1;
IMG_SKIP = 5;
IMG_STEP = 1;
MAX_IMG_COUNT = 100;
FILTER_SIZE = 5;
FILTER_WIDTH = 5;
BB_SIZE = 120;

% Attempt to acquire a toolbox license
global HaveToolbox;
HaveToolbox = ENABLE_TOOLBOX && license('checkout', 'Image_Toolbox');

% Load in the dataset
ImgData = myreadfolder(DATA_FOLDER, MAX_IMG_COUNT);

% Compute the median image
MedianIndices = [5 85 95];
MedianImgs = zeros(size(ImgData,1),    ...
                   size(ImgData,2),    ...
                   size(ImgData,3),    ...
                   size(MedianIndices, 2), ...
                   class(ImgData));


for Idx = 1:size(MedianIndices,2)
    ImgIdx = MedianIndices(Idx);

    Img = ImgData(:,:,:,ImgIdx);
    
    [ImgR, ImgG, ImgB] = processChannels(Img, FILTER_SIZE, FILTER_WIDTH);
    
    % Marginal Histogram along X-axis, Y-axis
    [CR, ThreshR] = xyhistmax(ImgR);
    [CG, ThreshG] = xyhistmax(ImgG);
    [CB, ThreshB] = xyhistmax(ImgB);
    
    Img = eraseRegion(Img, CR, BB_SIZE);
    Img = eraseRegion(Img, CG, BB_SIZE);
    Img = eraseRegion(Img, CB, BB_SIZE);
    
    MedianImgs(:,:,:,Idx) = Img;
end

MedImg =  median(MedianImgs, 4);

OldDirR = [0 0];
OldDirG = [0 0];
OldDirB = [0 0];

%****************************************************
%The variables used to link the objects movement

XLinkerR = [];
YLinkerR = [];
XLinkerG = [];
YLinkerG = [];
XLinkerB = [];
YLinkerB = [];

MissCount = 0;

for ImgIdx = IMG_SKIP:IMG_STEP:MAX_IMG_COUNT
    Img = ImgData(:,:,:,ImgIdx);
 
    [ImgR, ImgG, ImgB] = processChannels(Img, FILTER_SIZE, FILTER_WIDTH);
    
    % Marginal Histogram along X-axis, Y-axis
    [CR, ThreshR] = xyhistmax(ImgR);
    [CG, ThreshG] = xyhistmax(ImgG);
    [CB, ThreshB] = xyhistmax(ImgB);
   
    TImgR = cliprect(ImgR, CR, BB_SIZE)>ThreshR;
    TImgG = cliprect(ImgG, CG, BB_SIZE)>ThreshG;
    TImgB = cliprect(ImgB, CB, BB_SIZE)>ThreshB;
      
    %******************************************************
    %Calculate and display the bounding box for the image
    %Relative to the clipped image from the cliprect function
    [VerticesXR, VerticesYR, CentroidR, FalseImageR] = calcBoundingBox(TImgR);
    [VerticesXG, VerticesYG, CentroidG, FalseImageG] = calcBoundingBox(TImgG);
    [VerticesXB, VerticesYB, CentroidB, FalseImageB] = calcBoundingBox(TImgB);
    
    %******************************************************
    %If no image is detected, skip the current frame
    if min(VerticesXR) == 0 || min(VerticesXG) == 0 || min(VerticesXB) == 0
        MissCount = MissCount + 1;
        continue;
    end
    %Calculate the center of mass of the robot within a
    %bounding box
    [CenterMassXR,CenterMassYR] = calcBoundingBoxCM(VerticesXR, VerticesYR, TImgR);
    [CenterMassXG,CenterMassYG] = calcBoundingBoxCM(VerticesXG, VerticesYG, TImgG);
    [CenterMassXB,CenterMassYB] = calcBoundingBoxCM(VerticesXB, VerticesYB, TImgB);
    
    %Add variables for the center of mass of the 
    %robot relative to the original image
    trueCMXR = (CenterMassXR + CR(2) - size(TImgR, 2)/2);
    trueCMYR = (CenterMassYR + CR(1) - size(TImgR, 1)/2);
    trueCMXG = (CenterMassXG + CG(2) - size(TImgG, 2)/2);
    trueCMYG = (CenterMassYG + CG(1) - size(TImgG, 1)/2);
    trueCMXB = (CenterMassXB + CB(2) - size(TImgB, 2)/2);
    trueCMYB = (CenterMassYB + CB(1) - size(TImgB, 1)/2);
    
    %Store the true position of the bounding box centroid
    %relative to the coordinates of the original image 
    trueCentroidBBXR = (CentroidR(1) + CR(2) - size(TImgR, 2)/2);
    trueCentroidBBYR = (CentroidR(2) + CR(1) - size(TImgR, 1)/2);
    trueCentroidBBXG = (CentroidG(1) + CG(2) - size(TImgG, 2)/2);
    trueCentroidBBYG = (CentroidG(2) + CG(1) - size(TImgG, 1)/2);
    trueCentroidBBXB = (CentroidB(1) + CB(2) - size(TImgB, 2)/2);
    trueCentroidBBYB = (CentroidB(2) + CB(1) - size(TImgB, 1)/2);
    
    %************************************************
    %To link tracks on the estimated background image
    XLinkerR = [XLinkerR trueCMXR];
    YLinkerR = [YLinkerR trueCMYR];
    XLinkerG = [XLinkerG trueCMXG];
    YLinkerG = [YLinkerG trueCMYG];
    XLinkerB = [XLinkerB trueCMXB];
    YLinkerB = [YLinkerB trueCMYB];
    
    %Define unit vectors in the direction of the bounding
    %box centroid for each of the rgb channels respectively
    CenterMassR = [CenterMassXR CenterMassYR];
    DR = (CentroidR - CenterMassR);

    CenterMassG = [CenterMassXG CenterMassYG];
    DG = (CentroidG - CenterMassG);

    CenterMassB = [CenterMassXB CenterMassYB];
    DB = (CentroidB - CenterMassB);

    %Calculate the unit vectors for each channel
    DR = DR/norm(DR);
    DG = DG/norm(DG);
    DB = DB/norm(DB);
   
    %Colour for the orientation arrows in the bouding box
    LineColR = 'b-';
    LineColG = 'b-';
    LineColB = 'b-';
    
    %Colour for the orientation arrows on the main image
    LineColRArrow = [0 0 1];
    LineColGArrow = [0 0 1];
    LineColBArrow = [0 0 1];
 %Calculate the dot product between the arrows current 
 %orientation and its previous orientation. If the value
 %is less than 0.5, then the arrow is pointing in an incorrect
 %direction
    if dot(DR, OldDirR) < 0.5
  %Arrow is pointing in an incorrect direction,
  %therefore make the arrow red to indicate this.
        LineColR = 'r-';
        LineColRArrow = [1 0 0];
    end
    if dot(DG, OldDirG) < 0.5
        LineColG = 'r-';
        LineColGArrow = [1 0 0];
    end
    if dot(DB, OldDirB) < 0.5
        LineColB = 'r-';
        LineColBArrow = [1 0 0];
    end
    OldDirR = DR;
    OldDirG = DG;
    OldDirB = DB;
    
    figure(1);
    clf();
    %*****************************************************
    %Plotting the main images
    
    subplot(3,3,1:6);
    %myimshow(MedImg);
    myimshow(Img);
    hold on
    plot(XLinkerR, YLinkerR, 'xr-', XLinkerG, YLinkerG, 'xg-', XLinkerB, YLinkerB, 'xb-');
    xlabel(ImgIdx);
    myimshow(Img);
    colormap('default');
    hold on;
    %Plot the arrow on each of the cars to indicate their
    %orientation
    plot_arrow(trueCMXR,trueCMYR, trueCentroidBBXR+30*DR(1),trueCentroidBBYR+30*DR(2),...
	'linewidth',2,'headwidth',0.25,'headheight',0.33,'color',LineColRArrow,...
	'facecolor',LineColRArrow);
    hold on
    plot_arrow(trueCMXG,trueCMYG, trueCentroidBBXG+30*DG(1),trueCentroidBBYG+30*DG(2),...
	'linewidth',2,'headwidth',0.25,'headheight',0.33,'color',LineColGArrow,...
	'facecolor',LineColGArrow);
    hold on
    plot_arrow(trueCMXB,trueCMYB, trueCentroidBBXB+30*DB(1),trueCentroidBBYB+30*DB(2),...
	'linewidth',2,'headwidth',0.25,'headheight',0.33,'color',LineColBArrow,...
	'facecolor',LineColBArrow);
    
    %Plot the red channel with its corresponding bounding
    %box
    subplot(3,3,7);
    myimshow(TImgR);
    colormap('gray');
    hold on;
    plot(VerticesXR, VerticesYR, 'r-', 'LineWidth', 5);
    plot_arrow(CenterMassR(1),CenterMassR(2), CentroidR(1)+30*DR(1),...
	CentroidR(2)+30*DR(2),'linewidth',2,'headwidth',0.25,'headheight',0.33,...
	'color',LineColRArrow,'facecolor',LineColRArrow);
    xlabel('Red Channel');

    %Plot the green channel with its corresponding bounding
    %box
    subplot(3,3,8);
    myimshow(TImgG);
    colormap('gray');
    hold on;
    plot(VerticesXG, VerticesYG, 'g-', 'LineWidth', 5);
    plot_arrow(CenterMassG(1),CenterMassG(2), CentroidG(1)+30*DG(1),...
	CentroidG(2)+30*DG(2),'linewidth',2,'headwidth',0.25,'headheight',0.33,...
	'color',LineColRArrow,'facecolor',LineColRArrow);
    xlabel('Green Channel');

    %Plot the blue channel with its corresponding bounding
    %box
    subplot(3,3,9);
    myimshow(TImgB);
    colormap('gray');
    hold on;
    plot(VerticesXB, VerticesYB, 'b-', 'LineWidth', 5);
    plot_arrow(CenterMassB(1),CenterMassB(2), CentroidB(1)+30*DB(1),...
	CentroidB(2)+30*DB(2),'linewidth',2,'headwidth',0.25,'headheight',0.33,...
	'color',LineColBArrow,'facecolor',LineColBArrow);
    xlabel('Blue Channel');
    %*******************************************************
    %pause(0.1);
    input('...');
end
%*****************************************************
%Once the algorithm is finished, plot the background
%image with the linked tracks
clf();
myimshow(MedImg);
hold on
plot(XLinkerR, YLinkerR, 'xr-', XLinkerG, YLinkerG, 'xg-', XLinkerB, YLinkerB, 'xb-');
xlabel(ImgIdx);
input(int2str(MissCount));
toc