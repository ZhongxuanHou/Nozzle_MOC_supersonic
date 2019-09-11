clear,clc,close all

%% Description
% PROGRAM to compute the supersonic isentropic flow inside a nozzle of known shape.
% The method of characteristics is used for this purpose.
%   params gives the parameters for the flow properties
%   geom gives the parameters for the geometry and the mesh.
%%

params.gamma = 1.2;
params.R     = 320;
params.P     = 70.e5; % [Pa] Stagnation pressure
params.T     = 3000; % [K] Stagnation temperature

geom.yt    = 1  ; % [m] throat radius
geom.rhou  = 2  ; % [m] radius of upstream circular arc, required by MOC_2D_steady_irrotational_IVLINE
geom.rhod  = 0.5; % [m] radius of downstream circular arc
geom.NI    = 7 ; % Number of points on the initial-value line
geom.ta    = 15 ; % [deg] Attachment angle between circular arc and line
geom.te    = 15 ; % [deg] Exit lip point angle
geom.xe    = 10 ; % [m] Nozzle length
geom.circdownTheta = 1:1:geom.ta ; % From 1 degree to geom.ta
geom.delta = 1. ; % axisymmetric nozzle

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Geometry of the downstream circular arc
geom.circdownX =           geom.rhod*   sind( geom.circdownTheta ) ;
geom.circdownY = geom.yt + geom.rhod*(1-cosd( geom.circdownTheta)) ;

% The initial-value line is chosen as the line where V=0
ythroat = 0:geom.yt/(geom.NI-1):geom.yt;
% xsonic contains the absissae for the sonic line Mach=1 at the throat, not used here
% xvnull contains the absissae the the line V=0 at the throat
% uvnull contains the value of U on the line V=0
[xsonic,xvnull,uvnull] = MOC_2D_steady_irrotational_IVLINE ( geom , params , ythroat );

ythroat(1) += 1.e-6; % To avoid singularity on axis
uvnull(1)  += 1.e-6; % To avoid singularity on axis

X(1,1) = xvnull(1);
Y(1,1) = ythroat(1);
U(1,1) = uvnull(1);
V(1,1) = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Extend the solution from the initial-value line
disp('Computing the extent from the initial-value line...')
LENG_INDI(1)  = 1;
ind_patch_tri = 0;
ind_patch_quad = 0;
for I = 2:geom.NI
   X(1,I) = xvnull(I); Y(1,I) = ythroat(I); U(1,I) = uvnull(I); V(1,I) = 0;
   LENG_INDI(I)=1;
   for J = 2:2*(I-1) % Internal points
   % Point 1: right-running C-    ---> ( J-1 , I   )
   % Point 2: left -running C+    ---> ( J-1 , I-1 )
      [X(J,I),Y(J,I),U(J,I),V(J,I)] = MOC_2D_steady_irrotational_internal_point( X(J-1,I-1),Y(J-1,I-1),U(J-1,I-1),V(J-1,I-1),...
                                                                                 X(J-1,I  ),Y(J-1,I  ),U(J-1,I  ),V(J-1,I  ),...
                                                                                 params) ;
      LENG_INDI(I)++;
      if (J==2)
        ind_patch_tri ++;
        patch_i_tri(1:3,ind_patch_tri) = [ I   ; I-1 ; I ] ;
        patch_j_tri(1:3,ind_patch_tri) = [ J-1 ; J-1 ; J ] ;
      else
        ind_patch_quad ++;
        patch_i_quad(1:4,ind_patch_quad) = [ I   ; I-1 ; I-1 ; I ] ;
        patch_j_quad(1:4,ind_patch_quad) = [ J-1 ; J-2 ; J-1 ; J ] ;
      endif
   endfor
   % Point on the axis of symmetry
   J++;
   [X(J,I),Y(J,I),U(J,I),V(J,I)] = MOC_2D_steady_irrotational_internal_point( X(J-1,I),-Y(J-1,I),U(J-1,I),-V(J-1,I),...
                                                                              X(J-1,I), Y(J-1,I),U(J-1,I), V(J-1,I),...
                                                                              params) ;
   Y(J,I) += 1.e-6 ; % To avoid singularity on axis
   LENG_INDI(I)++;
   ind_patch_tri ++;
   patch_i_tri(1:3,ind_patch_tri) = [ I   ; I-1 ; I ] ;
   patch_j_tri(1:3,ind_patch_tri) = [ J-1 ; J-2 ; J ] ;
endfor

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Inverse wall point method for the downwards circular arc with prespecified points
disp('Computing the extent of the flow field determined by the initial-expansion contour...')
indI = I;
for I = 1:length(geom.circdownX)
   indI ++;
   theta4 = geom.circdownTheta(I);
   LENG_INDI(indI)=1;
   J=1;
   % Prescribed point on the circular arc -> get the values of U and V
   xtmp(1:3,1) = [ X(J+1,indI-1) ; X(J,indI-1) ; geom.circdownX(I) ];
   ytmp(1:3,1) = [ Y(J+1,indI-1) ; Y(J,indI-1) ; geom.circdownY(I) ];
   utmp(1:3,1) = [ U(J+1,indI-1) ; U(J,indI-1) ; 0.                ];
   vtmp(1:3,1) = [ V(J+1,indI-1) ; V(J,indI-1) ; 0.                ];
  [U(J,indI),V(J,indI),newx2(I),newy2(I),newu2(I),newv2(I)] = MOC_2D_steady_irrotational_wall_inverse ( xtmp,ytmp,utmp,vtmp,theta4,params) ;
   X(J,indI) = geom.circdownX(I);
   Y(J,indI) = geom.circdownY(I);
   
   J=2;
   for JJ = 2:LENG_INDI(indI-1) % Internal points
   % Point 1: right-running C-    ---> ( J-1 , indI   )
   % Point 2: left -running C+    ---> ( J   , indI-1 )
      [xtmp,ytmp,utmp,vtmp] = MOC_2D_steady_irrotational_internal_point( X(JJ,indI-1),Y(JJ,indI-1),U(JJ,indI-1),V(JJ,indI-1),...
                                                                         X(J-1,indI  ),Y(J-1,indI  ),U(J-1,indI  ),V(J-1,indI  ),...
                                                                         params) ;
      if (ytmp>=Y(1,indI))
       % If the C+ characteristic exits the geometry of the nozzle, delete the last computed point
         disp('... Deleting a point outside of the nozzle')
         continue;
      endif
      X(J,indI)=xtmp; Y(J,indI)=ytmp; U(J,indI)=utmp; V(J,indI)=vtmp;
      LENG_INDI(indI)++;
      ind_patch_quad ++;
      patch_i_quad(1:4,ind_patch_quad) = [ indI   ; indI-1 ; indI-1 ; indI ] ;
      patch_j_quad(1:4,ind_patch_quad) = [ J-1    ; JJ-1    ; JJ      ; J    ] ;
      J++;
   endfor
   % Point on the axis of symmetry
   [X(J,indI),Y(J,indI),U(J,indI),V(J,indI)] = MOC_2D_steady_irrotational_internal_point( X(J-1,indI),-Y(J-1,indI),U(J-1,indI),-V(J-1,indI),...
                                                                                          X(J-1,indI), Y(J-1,indI),U(J-1,indI), V(J-1,indI),...
                                                                                          params) ;
   Y(J,indI) += 1.e-6 ; % To avoid singularity on axis
   LENG_INDI(indI)++;
   ind_patch_tri ++;
   patch_i_tri(1:3,ind_patch_tri) = [ indI   ; indI-1 ; indI ] ;
   patch_j_tri(1:3,ind_patch_tri) = [ J-1    ; JJ    ; J    ] ;
endfor

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Direct wall point method for the linear part of the nozzle downstream of the circular arc
disp('Computing the extent of the flow field determined by the wall...')
while 1
   indI ++;
   indI
   % Wall point
   J=1;
   LENG_INDI(indI)=1;
   % Point 2: left -running C+    ---> ( J+1 , indI-1 )
   [X(J,indI),Y(J,indI),U(J,indI),V(J,indI)] = MOC_2D_steady_irrotational_wall ( X(J+1,indI-1),Y(J+1,indI-1),U(J+1,indI-1),V(J+1,indI-1),geom,params) ;
   if (X(J,indI) > geom.xe) 
     break;
   endif
   ind_patch_tri ++;
   patch_i_tri(1:3,ind_patch_tri) = [ indI-1   ; indI-1 ; indI ] ;
   patch_j_tri(1:3,ind_patch_tri) = [ J    ; J+1    ; J    ] ;
   
   for J = 2:LENG_INDI(indI-1)-1 % Internal point
     intersection=false;
   % Point 1: right-running C-    ---> ( J-1 , indI   )
   % Point 2: left -running C+    ---> ( J+1 , indI-1 )
     try
      [X(J,indI),Y(J,indI),U(J,indI),V(J,indI)] = MOC_2D_steady_irrotational_internal_point( X(J+1,indI-1),Y(J+1,indI-1),U(J+1,indI-1),V(J+1,indI-1),...
                                                                                             X(J-1,indI  ),Y(J-1,indI  ),U(J-1,indI  ),V(J-1,indI  ),...
                                                                                             params) ;
     catch
        % Possible intersection of characteristics -> shock -> solution not supported by the method of characteristics
        % Stop the C- characteristic and copy the values from the upstream C- characteristic that intersects
        X(J,indI) = X(J+1,indI-1);
        Y(J,indI) = Y(J+1,indI-1);
        U(J,indI) = U(J+1,indI-1);
        V(J,indI) = V(J+1,indI-1);
     end
     test1 = (X(J,indI)-X(J-1,indI))*(Y(J  ,indI-1)-Y(J-1,indI)) - (Y(J,indI)-Y(J-1,indI))*(X(J  ,indI-1)-X(J-1,indI)) ;
     test2 = (X(J,indI)-X(J-1,indI))*(Y(J+1,indI-1)-Y(J-1,indI)) - (Y(J,indI)-Y(J-1,indI))*(X(J+1,indI-1)-X(J-1,indI)) ;
     if (test1*test2<=0) 
        % Intersection of characteristics
        intersection = true;
        break;
     endif
     
%     if (X(J,indI) < X(J-1,indI))
%       disp(['Delete that node ',num2str(indI),', ',num2str(J)])
%     endif
     
     LENG_INDI(indI) ++;
     ind_patch_quad ++;
     patch_i_quad(1:4,ind_patch_quad) = [ indI   ; indI-1 ; indI-1 ; indI ] ;
     patch_j_quad(1:4,ind_patch_quad) = [ J-1    ; J      ; J+1    ; J    ] ;
   endfor
   
   if (intersection)
    % Copy the rest of the data for the C- characteristic from the upstream C- characteristic
      loclen = LENG_INDI(indI-1) - J ;
      X(J:J+loclen-1,indI) = X(J+1:LENG_INDI(indI-1),indI-1);
      Y(J:J+loclen-1,indI) = Y(J+1:LENG_INDI(indI-1),indI-1);
      U(J:J+loclen-1,indI) = U(J+1:LENG_INDI(indI-1),indI-1);
      V(J:J+loclen-1,indI) = V(J+1:LENG_INDI(indI-1),indI-1);
      LENG_INDI(indI) = LENG_INDI(indI) + loclen ;
      
      ind_patch_tri ++;
      patch_i_tri(1:3,ind_patch_tri) = [ indI   ; indI-1 ; indI ] ;
      patch_j_tri(1:3,ind_patch_tri) = [ J-1    ; J    ; J    ] ;
      
   else
   % Point on the axis of symmetry
      J++;
      [X(J,indI),Y(J,indI),U(J,indI),V(J,indI)] = MOC_2D_steady_irrotational_internal_point( X(J-1,indI),-Y(J-1,indI),U(J-1,indI),-V(J-1,indI),...
                                                                                             X(J-1,indI), Y(J-1,indI),U(J-1,indI), V(J-1,indI),...
                                                                                             params) ;
      Y(J,indI) += 1.e-6 ; % To avoid singularity on axis
      LENG_INDI(indI)++;
      ind_patch_tri ++;
      patch_i_tri(1:3,ind_patch_tri) = [ indI   ; indI-1 ; indI ] ;
      patch_j_tri(1:3,ind_patch_tri) = [ J-1    ; LENG_INDI(indI-1)    ; J    ] ;
   endif
end

% The last point computed in the last loop is located downstream of the nozzle exit lip point
% Compute the right-running C- from the nozzle exit lip point with the help of the inverse wall method
disp('Computing the flow from the nozzle exit lip...')
[abc,y4,theta4] = MOC_2D_steady_irrotational_get_geometry(geom.xe,2,geom) ;
theta4 = atand(theta4);
xtmp(1:3,1) = [ X(J+1,indI-1) ; X(J,indI-1) ; geom.xe ];
ytmp(1:3,1) = [ Y(J+1,indI-1) ; Y(J,indI-1) ; y4 ];
utmp(1:3,1) = [ U(J+1,indI-1) ; U(J,indI-1) ; 0.                ];
vtmp(1:3,1) = [ V(J+1,indI-1) ; V(J,indI-1) ; 0.                ];
[U(J,indI),V(J,indI),newx2(I),newy2(I),newu2(I),newv2(I)] = MOC_2D_steady_irrotational_wall_inverse ( xtmp,ytmp,utmp,vtmp,theta4,params) ;
X(J,indI) = geom.xe;
Y(J,indI) = y4;
for J = 2:LENG_INDI(indI-1)-1
   % Point 1: right-running C-    ---> ( J-1 , indI   )
   % Point 2: left -running C+    ---> ( J+1 , indI-1 )
   [X(J,indI),Y(J,indI),U(J,indI),V(J,indI)] = MOC_2D_steady_irrotational_internal_point( X(J+1,indI-1),Y(J+1,indI-1),U(J+1,indI-1),V(J+1,indI-1),...
                                                                                          X(J-1,indI  ),Y(J-1,indI  ),U(J-1,indI  ),V(J-1,indI  ),...
                                                                                          params) ;
   LENG_INDI(indI) ++;
   ind_patch_quad ++;
   patch_i_quad(1:4,ind_patch_quad) = [ indI   ; indI-1 ; indI-1 ; indI ] ;
   patch_j_quad(1:4,ind_patch_quad) = [ J-1    ; J      ; J+1    ; J    ] ;
endfor
% Point on axis of symmetry
J++;
[X(J,indI),Y(J,indI),U(J,indI),V(J,indI)] = MOC_2D_steady_irrotational_internal_point( X(J-1,indI),-Y(J-1,indI),U(J-1,indI),-V(J-1,indI),...
                                                                                       X(J-1,indI), Y(J-1,indI),U(J-1,indI), V(J-1,indI),...
                                                                                       params) ;
Y(J,indI) += 1.e-6 ; % To avoid singularity on axis
ind_patch_tri ++;
patch_i_tri(1:3,ind_patch_tri) = [ indI   ; indI-1 ; indI ] ;
patch_j_tri(1:3,ind_patch_tri) = [ J-1    ; LENG_INDI(indI-1)    ; J    ] ;
      
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('Plotting the results...')
fig1=figure(1);
plot(X(1,:),Y(1,:),'k','linewidth',2); grid on; hold on; xlabel('X [m]'); ylabel('Y [m]');
scatterX = reshape(X,[],1); scatterY = reshape(Y,[],1);
scatterU = reshape(U,[],1); scatterV = reshape(V,[],1);
condplot = scatterU>0;
[Mach,pressure,density,temperature,sound] = MOC_2D_steady_irrotational_get_thermo(U,V,params);
%scatter(scatterX(condplot),scatterY(condplot),100,Mach(condplot),'filled'); colormap hsv; colorbar;
%quiver(X,Y,U,V)

for I=1:ind_patch_tri
  patch_x_tri(1:3,I) = [ X(patch_j_tri(1,I),patch_i_tri(1,I)) ; ...
                         X(patch_j_tri(2,I),patch_i_tri(2,I)) ; ...
                         X(patch_j_tri(3,I),patch_i_tri(3,I)) ; ] ;
  patch_y_tri(1:3,I) = [ Y(patch_j_tri(1,I),patch_i_tri(1,I)) ; ...
                         Y(patch_j_tri(2,I),patch_i_tri(2,I)) ; ...
                         Y(patch_j_tri(3,I),patch_i_tri(3,I)) ; ] ;
  patch_c_tri(1:3,I) = [ pressure(patch_j_tri(1,I),patch_i_tri(1,I)) ; ...
                         pressure(patch_j_tri(2,I),patch_i_tri(2,I)) ; ...
                         pressure(patch_j_tri(3,I),patch_i_tri(3,I)) ; ] ;
endfor

for I=1:ind_patch_quad
  patch_x_quad(1:4,I) = [ X(patch_j_quad(1,I),patch_i_quad(1,I)) ; ...
                          X(patch_j_quad(2,I),patch_i_quad(2,I)) ; ...
                          X(patch_j_quad(3,I),patch_i_quad(3,I)) ; ...
                          X(patch_j_quad(4,I),patch_i_quad(4,I)) ; ] ;
  patch_y_quad(1:4,I) = [ Y(patch_j_quad(1,I),patch_i_quad(1,I)) ; ...
                          Y(patch_j_quad(2,I),patch_i_quad(2,I)) ; ...
                          Y(patch_j_quad(3,I),patch_i_quad(3,I)) ; ...
                          Y(patch_j_quad(4,I),patch_i_quad(4,I)) ; ] ;
  patch_c_quad(1:4,I) = [ pressure(patch_j_quad(1,I),patch_i_quad(1,I)) ; ...
                          pressure(patch_j_quad(2,I),patch_i_quad(2,I)) ; ...
                          pressure(patch_j_quad(3,I),patch_i_quad(3,I)) ; ...
                          pressure(patch_j_quad(4,I),patch_i_quad(4,I)) ; ] ;
endfor

%patch(patch_x_tri,patch_y_tri,patch_c_tri,'LineStyle','none');
%patch(patch_x_quad,patch_y_quad,patch_c_quad,'LineStyle','none'); colormap(jet(256)) ; colorbar;

% To show the left- and right-running characteristics
patch(patch_x_tri,patch_y_tri,patch_c_tri,'LineStyle','-');
patch(patch_x_quad,patch_y_quad,patch_c_quad,'LineStyle','-'); colormap(jet(256)) ; %colorbar;

%ylim([0 Y(1,end)])
axis equal; 

##saveas(fig1,'Characteristics.pdf')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fig2=figure(2);
condplot=zeros(size(X,1),size(X,2)); condplot = logical(condplot);
wallnodesJ = geom.NI+1 : size(X,2) ;
for I=1:size(X,2)
  axisnodesJ = find(U(:,I),1,'last');
  condplot( axisnodesJ , I ) = true;
endfor
disp('Postprocessing the results...')
[chocked] = get_Laval_theory(geom,params,X(1,wallnodesJ),Y(1,wallnodesJ)) ;
semilogy(X(1,wallnodesJ),pressure(1,wallnodesJ)/params.P,'r','linewidth',2); hold on; % Wall nodes
semilogy(X(condplot),pressure(condplot)/params.P,'b','linewidth',2); % Axis nodes
semilogy(X(1,wallnodesJ),chocked.pressure,'k','linewidth',2); % 1D theory on axis
grid on; ylabel('Static pressure / Stagnation pressure [-]'); xlabel('X [m]');
legend('Wall','Axis','1D')
axis([0 geom.xe 0.01 1])
##saveas(fig2,'Pressure.pdf')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fig3=figure(3);
plot(X(1,wallnodesJ),Mach(1,wallnodesJ),'r','linewidth',2); hold on; % Wall nodes
plot(X(condplot),Mach(condplot),'b','linewidth',2); % Axis nodes
plot(X(1,wallnodesJ),chocked.mach,'k','linewidth',2); % 1D theory on axis
grid on; ylabel('Mach number [-]'); xlabel('X [m]');
legend('Wall','Axis','1D')
axis([0 geom.xe 1 4])
##saveas(fig3,'Mach_number.pdf')