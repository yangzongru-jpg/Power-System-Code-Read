%用yalmip的kkt命令
clear
clc
%参数
price_day_ahead=[0.35;0.33;0.3;0.33;0.36;0.4;0.44;0.46;0.52;0.58;0.66;0.75;0.81;0.76;0.8;0.83;0.81;0.75;0.64;0.55;0.53;0.47;0.40;0.37];
price_b=1.2*price_day_ahead;
price_s=0.8*price_day_ahead;
lb=0.8*price_day_ahead;
ub=1.2*price_day_ahead;
T_1=[1;1;1;1;1;1;0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;1;1;1];
T_2=[1;1;1;1;1;1;1;1;0;0;0;0;1;1;1;0;0;0;0;1;1;1;1;1];
T_3=[0;0;0;0;0;0;0;1;1;1;1;1;1;1;1;1;1;1;1;1;0;0;0;0];
index1=find(T_1==0);index2=find(T_2==0);index3=find(T_3==0);
%定义变量
Ce=sdpvar(24,1);%电价
z=binvar(24,1);%购售电状态
u=binvar(24,1);%储能状态
Pb=sdpvar(24,1);%日前购电
Pb_day=sdpvar(24,1);%实时购电
Ps_day=sdpvar(24,1);%实时售电
Pdis=sdpvar(24,1);%储能放电
Pch=sdpvar(24,1);%储能充电
Pc1=sdpvar(24,1);%一类车充电功率
Pc2=sdpvar(24,1);%二类车充电功率
Pc3=sdpvar(24,1);%三类车充电功率
S=sdpvar(24,1);%储荷容量
for t=2:24
    S(t)=S(t-1)+0.9*Pch(t)-Pdis(t)/0.9;
end
%内层
CI=[sum(Pc1)==50*(0.9*24-9.6),sum(Pc2)==20*(0.9*24-9.6),sum(Pc3)==10*(0.9*24-9.6),Pc1>=0,Pc2>=0,Pc3>=0,Pc1<=50*3,Pc2<=20*3,Pc3<=10*3,Pc1(index1)==0,Pc2(index2)==0,Pc3(index3)==0];%电量需求约束
OI=sum(Ce.*(Pc1+Pc2+Pc3));
ops=sdpsettings('solver','gurobi','kkt.dualbounds',0);
[K,details] = kkt(CI,OI,Ce,ops);%建立KKT系统，Ce为参量
%外层
CO=[lb<=Ce<=ub,mean(Ce)==0.5,Pb>=0,Ps_day<=Pdis,Pb_day>=0,Pb_day<=1000*z,Ps_day>=0,Ps_day<=1000*(1-z),Pch>=0,Pch<=1000*u,Pdis>=0,Pdis<=1000*(1-u)];%边界约束
CO=[CO,Pc1+Pc2+Pc3+Pch-Pdis==Pb+Pb_day-Ps_day];%能量平衡
CO=[CO,sum(0.9*Pch-Pdis/0.9)==0,S(24)==2500,S>=0,S<=5000];%SOC约束
OO=-(details.b'*details.dual+details.f'*details.dualeq)+sum(price_s.*Ps_day-price_day_ahead.*Pb-price_b.*Pb_day);%目标函数
optimize([K,CI,CO,boundingbox([CI,CO]),details.dual<=1],-OO)


Ce=value(Ce);%电价
Pb=value(Pb);%日前购电
Pb_day=value(Pb_day);%实时购电
Ps_day=value(Ps_day);%实时购电
Pdis=value(Pdis);%储能放电
Pch=value( Pch);%储能充电
Pb_day=value(Pb_day);%实时购电
Pb_day=value(Pb_day);%实时购电
Pc1=value(Pc1);%一类车充电功率
Pc2=value(Pc2);%二类车充电功率
Pc3=value(Pc3);%三类车充电功率
S=value(S);%储荷容量

figure(1)
plot(Pc1,'-*','linewidth',1.5)
grid
hold on
plot(Pc2,'-*','linewidth',1.5)
hold on
plot(Pc3,'-*','linewidth',1.5)
title('三类电动汽车充电功率')
legend('类型1','类型2','类型3')
xlabel('时间')
ylabel('功率')

figure(2)
bar(Pdis,0.5,'linewidth',0.01)
grid
hold on
bar(Pch,0.5,'linewidth',0.01)
hold on
plot(S,'-*','linewidth',1.5)
axis([0.5 24.5 0 5000]);
title('储能充电功率')
legend('充电功率','放电功率','蓄电量')
xlabel('时间')
ylabel('功率')

figure(3)
yyaxis left;
bar(Pb_day,0.5,'linewidth',0.01)
hold on
bar(Ps_day,0.5,'linewidth',0.01)
axis([0.5 24.5 0 1200])
xlabel('时间')
ylabel('功率')
yyaxis right;
plot(Ce,'-*','linewidth',1.5)
% legend('电价结果')
xlabel('时间')
ylabel('电价')
legend('日前购电','日前售电','电价优化');

figure(4)
plot(Ce,'-*','linewidth',1.5)
grid
hold on
plot(price_b,'-*','linewidth',1.5)
hold on
plot(price_s,'-*','linewidth',1.5)
title('电价优化结果')
legend('优化电价','购电电价','售电电价')
xlabel('时间')
ylabel('电价')