clc;
clear;
close all;
%% 此程序为加了储能，并不考虑经济性，储能直接按照第八天的最大值来配置,进行十五天调度
%% 定义
biaoge = xlsread('附件2');
LOAD = biaoge(:,2);
WIND = biaoge(:,3);
mpc = [600,300,150;
    180,90,45;
    0.72,0.75,0.79;
    786.8,451.32,1049.5;
    30.42,65.12,139.6;
    0.226,0.588,0.785];
tan = 0;
wind = [0.045,0.3];
loadloss = 8;
Bat =[3000,3000,0.05,0.9,0.5]; % [单位功率成本、单位能量成本、单位运维成本、充放电功率、初始容量]
% 注：储能电池初始荷电状态为0.5、最大允许荷电状态为0.95、最小允许荷电状态为0.05
%% 调度
Load = LOAD;
Wind = WIND;

[Result,Cost,PDE,PWind,S_Bat,Bat_limit,P_Bat,Pdis,Pcha] = Yalmip_Cplex3(Load,Wind,mpc,tan,wind,Bat);

zongfeng = sum(Wind-PWind');

S = [];SOC = [];
SOC(1) = S_Bat*Bat(5);
for t = 1:size(Load)
    S(t) = S_Bat*Bat(5) - sum(Pdis(1:t)/Bat(4) + Bat(4)*Pcha(1:t));
    SOC(t+1) = S(t);
end
SOC = SOC/S_Bat;
%% 画图
figure(1);
bar(PDE(1,:));
hold on
bar(PWind);
bar(P_Bat);
plot(Load,'r-*');
plot(PDE(1,:)+PWind+P_Bat,'k--')
hold off
legend('一号机组','风电机组','储能电池','负荷需求','总发电功率');
xlabel('时间/15min');
ylabel('功率/MW');
title('机组15日发电计划曲线');

figure(2);
plot(PWind,'r-^');
hold on
plot(Wind,'b--*');
hold off
legend('风电实际出力','风电功率情况');
xlabel('时间(15min)');
ylabel('功率(MW)');
title('风电情况');

figure(4);
plot(P_Bat,'LineWidth',2);
legend('储能功率');
xlabel('时间/15min');
ylabel('功率/MW');
title('储能系统功率');

figure(5);
plot(SOC,'LineWidth',2);
legend('储能容量');
xlabel('时间/15min');
ylabel('储能系统荷电状态');
title('储能SOC');

