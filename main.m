% Clear any existing state
clear all;
clc;
clf;

% Configuration section
DATA_FOLDER = 'data2/';
ENABLE_TOOLBOX = 1;
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
MedianIndices = [5 75 80];
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

for ImgIdx = 5:MAX_IMG_COUNT
    Img = ImgData(:,:,:,ImgIdx);
 
    [ImgR, ImgG, ImgB] = processChannels(Img, FILTER_SIZE, FILTER_WIDTH);
    
    % Marginal Histogram along X-axis, Y-axis
    [CR, ThreshR] = xyhistmax(ImgR);
    [CG, ThreshG] = xyhistmax(ImgG);
    [CB, ThreshB] = xyhistmax(ImgB);
   
    TImgR = cliprect(ImgR, CR, BB_SIZE)>ThreshR;
    TImgG = cliprect(ImgG, CG, BB_SIZE)>ThreshG;
    TImgB = cliprect(ImgB, CB, BB_SIZE)>ThreshB;
    
    %Calculating the bounding box for the thresholded image
    %To determine the center of mass of the objects
    %***********************************
    
    CenterMass = calcCenterMass(TImgR, TImgG, TImgB);
   
    
    %******************************************************
    %Calculate and display the bounding box for the image   
    [VerticesXR, VerticesYR, CentroidR, FalseImageR] = calcBoundingBox(TImgR);
    [VerticesXG, VerticesYG, CentroidG, FalseImageG] = calcBoundingBox(TImgG);
    [VerticesXB, VerticesYB, CentroidB, FalseImageB] = calcBoundingBox(TImgB);
    
    %******************************************************
    %Calculate the orientation for each robot
    if min(VerticesXR) == 0 || min(VerticesXG) == 0 || min(VerticesXB) == 0
        continue;
    end

    [CenterMassXR,CenterMassYR] = calcBoundingBoxCM(VerticesXR, VerticesYR, TImgR);
    [CenterMassXG,CenterMassYG] = calcBoundingBoxCM(VerticesXG, VerticesYG, TImgG);
    [CenterMassXB,CenterMassYB] = calcBoundingBoxCM(VerticesXB, VerticesYB, TImgB);
    
    %Add variables for the true center of mass
    trueCMXR = (CenterMassXR + CR(2) - BB_SIZE/2);
    trueCMYR = (CenterMassYR + CR(1) - BB_SIZE/2);
    trueCMXG = (CenterMassXG + CG(2) - BB_SIZE/2);
    trueCMYG = (CenterMassYG + CG(1) - BB_SIZE/2);
    trueCMXB = (CenterMassXB + CB(2) - BB_SIZE/2);
    trueCMYB = (CenterMassYB + CB(1) - BB_SIZE/2);
    %Store the previous Center of mass of the objects
    %for plotting purposes
    
    %************************************************
    %To link the points on the estimated background image
    XLinkerR = [XLinkerR trueCMXR];
    YLinkerR = [YLinkerR trueCMYR];
    XLinkerG = [XLinkerG trueCMXG];
    YLinkerG = [YLinkerG trueCMYG];
    XLinkerB = [XLinkerB trueCMXB];
    YLinkerB = [YLinkerB trueCMYB];
    
    %Define unit vectors in the direction of the Centroid
    CenterMassR = [CenterMassXR CenterMassYR];
    DR = (CentroidR - CenterMassR);

    CenterMassG = [CenterMassXG CenterMassYG];
    DG = (CentroidG - CenterMassG);

    CenterMassB = [CenterMassXB CenterMassYB];
    DB = (CentroidB - CenterMassB);

    %The unit vectors for each channel
    DR = DR/norm(DR);
    DG = DG/norm(DG);
    DB = DB/norm(DB);
   
    LineColR = 'b-';
    LineColG = 'b-';
    LineColB = 'b-';
    
    if dot(DR, OldDirR) < 0.5
        LineColR = 'r-';
    end
    if dot(DG, OldDirG) < 0.5
        LineColG = 'r-';
    end
    if dot(DB, OldDirB) < 0.5
        LineColB = 'r-';
    end
    OldDirR = DR;
    OldDirG = DG;
    OldDirB = DB;
    
    figure(1);
    clf();
    
    subplot(3,3,1:6);
    %myimshow(MedImg);
    myimshow(Img);
    colormap('default');
    hold on;
    plot(XLinkerR, YLinkerR, 'xr-', XLinkerG, YLinkerG, 'xg-', XLinkerB, YLinkerB, 'xb-');
    xlabel(ImgIdx);

    subplot(3,3,7);
    myimshow(TImgR);
    colormap('gray');
    hold on;
    plot(VerticesXR, VerticesYR, 'r-', 'LineWidth', 2);
    plot([CenterMassR(1),CentroidR(1)+30*DR(1)], [CenterMassR(2), CentroidR(2)+30*DR(2)], LineColR, 'LineWidth',2);
    xlabel('red');

    subplot(3,3,8);
    myimshow(TImgG);
    colormap('gray');
    hold on;
    plot(VerticesXG, VerticesYG, 'g-', 'LineWidth', 2);
    plot([CenterMassG(1),CentroidG(1)+30*DG(1)], [CenterMassG(2), CentroidG(2)+30*DG(2)], LineColG, 'LineWidth',2);
    xlabel('green');

    subplot(3,3,9);
    myimshow(TImgB);
    colormap('gray');
    hold on;
    plot(VerticesXB, VerticesYB, 'b-', 'LineWidth', 2);
    plot([CenterMassB(1),CentroidB(1)+30*DB(1)], [CenterMassB(2), CentroidB(2)+30*DB(2)], LineColB, 'LineWidth',2);
    xlabel('blue');

    pause(0.1);
end
