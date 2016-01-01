create or replace function FN_T_AheadSettleOneQty(
  p_ApplyID   varchar2,    --������Ա��
  p_CommodityID varchar2,   --��Ʒ����
  p_Price         number,  --���ռ�
  p_BS_Flag     number,  --������־
    p_CustomerID    varchar2,     --���׿ͻ�ID
    p_OCustomerID    varchar2,     --�Է����׿ͻ�ID
    p_HoldQty      number,   --���ճֲ����������ǵֶ�����
  p_GageQty      number   --���յֶ�����
) return number
/****
 * ������������ǰ����
 * 1��ע�ⲻҪ�ύcommit����Ϊ��ĺ���Ҫ��������
 * ����ֵ
 * 1 �ɹ�
 * -1  �ɽ��ճֲ���������
 * -2  �ɽ��յֶ���������
 * -3  ���ճֲ��������ڿɽ��ճֲ�����
 * -4  ���յֶ��������ڿɵֶ�����
 * -100 ��������
****/
as
  v_version varchar2(10):='1.0.2.1';
    v_CommodityID varchar2(16);
    v_CustomerID        varchar2(40);
    v_FirmID varchar2(32);
    v_HoldQty  number;
    v_HoldSumQty     number(10);
    v_frozenQty      number(10);
    v_Margin         number(15,2):=0;
    v_Margin_one         number(15,2):=0;
    v_closeFL_one         number(15,2):=0;    --һ����¼�Ľ���ӯ��
    v_CloseFL         number(15,2):=0;        --����ӯ���ۼ�
    v_Fee_one         number(15,2):=0;    --һ����¼�Ľ���������
    v_Fee         number(15,2):=0;        --�����������ۼ�
  v_Assure         number(15,2):=0;
  v_Assure_one         number(15,2):=0;
    v_Payout         number(15,2):=0;
    v_Payout_one         number(15,2):=0;
    v_BS_Flag           number(2);
    v_Price         number(15,2);
    v_ContractFactor    number(12,2);
    v_MarginPriceType           number(1);
    v_MarginPrice    number(15,2);  --����ɽ���֤��ļ۸�
  v_HoldFunds    number(15,2):=0;  --ƽ��ʱӦ�˳ֲֽ��������ֶ���
  v_CustomerHoldFunds    number(15,2):=0;  --ƽ��ʱӦ�˳ֲֽ������ֶ���
    v_TradeDate date;
  v_A_HoldNo number(15);
  v_ID number(15);
  v_AddedTaxFactor T_Commodity.AddedTaxFactor%type;--��ֵ˰��ϵ��=AddedTax/(1+AddedTax)
  v_GageQty     number(10);
  v_CloseAddedTax_one   number(15,2); --����ӯ����ֵ˰
  v_CloseAddedTax         number(15,2):=0;        --����ӯ����ֵ˰�ۼ�
  v_unCloseQty     number(10):=p_HoldQty; --δƽ�����������м����
  v_unCloseQtyGage     number(10):=p_GageQty; --δƽ�����������м����
  v_tradedAmount   number(10):=0;  --�ɽ�����
  v_tradedAmountGage   number(10):=0;  --�ɽ�����
  v_CloseAlgr           number(2);
  v_num            number(10);
  v_Balance    number(15,2);
  v_F_FrozenFunds   number(15,2);
  type cur_T_HoldPosition is ref cursor;
  v_HoldPosition cur_T_HoldPosition;
  v_sql varchar2(500);
  v_orderby  varchar2(100);
  v_closeTodayHis        number(2);    --ƽ��ֻ�����ʷ��(0ƽ��֣�1ƽ��ʷ��)
  v_YesterBalancePrice    number(15,2);
  v_AtClearDate          date;
  v_LowestSettleFee             number(15,2) default 0;
  v_GageMode number(2);--�ֶ�ģʽ����0ȫ�ֶ���1��ֶ�����ֶ�ʱҪ���㸡����2009-10-14

  v_GageFrozenQty number(10);--add by yukx 20100428 �ֶ���������

  v_IsChargeMargin number(2);-- �Ƿ���ȡ���ձ�֤��(0 ����ȡ��1��ȡ)  add by zhangjian- 20110713
  v_SettlementMargin_one     number(15,2):=0;-- ���ձ�֤��
  v_SettlementMargin     number(15,2):=0;-- ���ձ�֤���ۼ�
  v_aheadSettlePriceType number(2);--��ǰ���ռ۸����� 0:�������۽��� 1���������۽���
  v_settlePrice number(15,2);--���ռ۸�
  v_settleMachID number(10):=0;--���ճֲ���ϸ�� ID
  v_totalRef         number(15,2):=0;  --��׼�������ֵ
  v_bFirmID   varchar2(32);  --�򷽽�����ID
  v_SettlementMargin_B      number(15,2):=0; --�򷽽��ձ�֤��
  v_settlePirce_B    number(15,6):=0;--�򷽽��ռ۸�
  v_bPayout         number(15,2):=0; --�򷽻���
   v_TaxInclusive     number(1);   --��Ʒ�Ƿ�˰ 0��˰  1����˰   duanbaodi 20150730
begin
    v_CustomerID := p_CustomerID;
      v_CommodityID := p_CommodityID;
        v_BS_Flag := p_BS_Flag;
        --��ס���׿ͻ��ֲֺϼƣ��Է�ֹ��������
        select HoldQty,FrozenQty,GageQty,GageFrozenQty
        into v_HoldSumQty, v_frozenQty,v_GageQty,v_GageFrozenQty
        from T_CustomerHoldSum
        where CustomerID = v_CustomerID
          and CommodityID = v_CommodityID
          and bs_flag = v_BS_Flag for update;
        /*  �ɽ��ճֲ���������Ϳɽ��յֶ�����������ж��ö��������͵ֶ����������ж�
        --�ɽ��ճֲ���������
        if(p_HoldQty > v_HoldSumQty-v_frozenQty) then
            rollback;
            return -1;
        end if;
        --�ɽ��յֶ���������
        if(p_GageQty > v_GageQty) then
            rollback;
            return -2;
        end if;
        */
        --�ɽ��ճֲ���������
        if(p_HoldQty > v_frozenQty) then
            rollback;
            return -1;
        end if;
        --�ɽ��յֶ���������
        if(p_GageQty > v_GageFrozenQty) then
            rollback;
            return -2;
        end if;
         --select   seq_T_SettleMatch.nextVal into v_settleMachNumber from dual;
         --v_settleMachNumber:=p_settleMachNumber;

        --��ȡƽ���㷨,�ֶ�ģʽ,�Ƿ���ȡ���ձ�֤�� , ��֤��������ͣ���ֵ˰����Լ����,�Ƿ�˰
        select CloseAlgr,GageMode,ASMarginType into v_CloseAlgr,v_GageMode,v_IsChargeMargin from T_A_Market;
       /* select Contractfactor,MarginPriceType,AddedTaxFactor,LastPrice,LowestSettleFee
        into v_ContractFactor,v_MarginPriceType,v_AddedTaxFactor,v_YesterBalancePrice,v_LowestSettleFee
        from T_Commodity where CommodityID=v_CommodityID;   duanbaodi 20150730 */

         select Contractfactor,MarginPriceType,AddedTaxFactor,LastPrice,LowestSettleFee,TaxInclusive
        into v_ContractFactor,v_MarginPriceType,v_AddedTaxFactor,v_YesterBalancePrice,v_LowestSettleFee,v_TaxInclusive
        from T_Commodity where CommodityID=v_CommodityID;  -- ���� �Ƿ�˰�ֶβ�ѯ duanbaodi 20150730

      select TradeDate into v_TradeDate from T_SystemStatus;

        --����ƽ���㷨(0�ȿ���ƽ��1����ƽ��2�ֲ־���ƽ��(������)ѡ����������
        if(v_CloseAlgr = 0) then
         v_orderby := ' order by a.A_HoldNo ';
        elsif(v_CloseAlgr = 1) then
           v_orderby := ' order by a.A_HoldNo desc ';
       end if;

         select  aheadSettlePriceType  into v_aheadSettlePriceType from t_commodity  where commodityid=p_CommodityID;--��ȡ��ǰ���ս��ռ۸�����


      v_sql := 'select  a.a_holdno,FirmID,price,(a.HoldQty-nvl(b.FrozenQty,0)),GageQty,nvl(b.FrozenQty,0),a.AtClearDate from T_holdposition a,(select A_HoldNo,nvl(sum(FrozenQty),0) FrozenQty from T_SpecFrozenHold group by A_HoldNo) b ' ||
                 ' where (a.HoldQty+a.GageQty) > 0 and a.A_HoldNo=b.A_HoldNo(+) and CustomerID=''' || v_CustomerID ||
                 ''' and CommodityID =''' || v_CommodityID || ''' and bs_flag = ' || v_BS_Flag || v_orderby;


         --�����ֲ���ϸ�����������˵�ָ��ƽ�ֶ��������
            open v_HoldPosition for v_sql;
            loop
                fetch v_HoldPosition into v_a_holdno, v_FirmID, v_price, v_holdqty,v_GageQty,v_frozenQty,v_AtClearDate;
                exit when v_HoldPosition%NOTFOUND;

                if(v_aheadSettlePriceType=0)then --����������۽���
                      v_settlePrice:=v_Price;
                      else                   --����������۽���
                       v_settlePrice:=p_Price;
                      end  if;

                --����˱ʳֲ�ȫ����ָ��ƽ�ֶ�����û�еֶ���ָ����һ����¼
              --2011-01-12 by chenxc �޸ĵ��ֲ���ϸ�ĳֲ�����Ϊ0���ֶ�������Ϊ0����ǰ���շǵֶ��Ļ����һ���ֲּ�¼����0�ĵ����ճֲ���ϸ������֮��Ȼ
                if((v_holdqty <> 0 and v_unCloseQty>0) or (v_GageQty <> 0 and v_unCloseQtyGage>0)) then
                  --��0
                  v_tradedAmount:=0;
                  v_tradedAmountGage:=0;
                  v_Payout_one := 0;
                  --1������Ӧ�˿���
                  if(v_holdqty > 0) then
                    if(v_holdqty<=v_unCloseQty) then
                        v_tradedAmount:=v_holdqty;
                    else
                        v_tradedAmount:=v_unCloseQty;
                    end if;
                    --����Ӧ�˱�֤�𣬸�������ѡ�񿪲ּۻ�������������
            if(v_MarginPriceType = 1) then
                  v_MarginPrice := v_YesterBalancePrice;
              elsif(v_MarginPriceType = 2) then
              --�ж���ƽ��ֻ���ƽ��ʷ��
                if(trunc(v_TradeDate) = trunc(v_AtClearDate)) then
                    v_closeTodayHis := 0;
                else
                  v_closeTodayHis := 1;
                end if;
              if(v_closeTodayHis = 0) then  --ƽ���
                v_MarginPrice := v_price;
              else  --ƽ��ʷ��
                    v_MarginPrice := v_YesterBalancePrice;
                end if;
            else  -- default type is 0
              v_MarginPrice := v_price;
            end if;
                    v_Margin_one := FN_T_ComputeMargin(v_FirmID,v_CommodityID,v_BS_Flag,v_tradedAmount,v_MarginPrice);
                    if(v_Margin_one < 0) then
                        Raise_application_error(-20040, 'computeMargin error');
                    end if;
                --���㵣����
                v_Assure_one := FN_T_ComputeAssure(v_FirmID,v_CommodityID,v_BS_Flag,v_tradedAmount,v_MarginPrice);
                if(v_Assure_one < 0) then
                    Raise_application_error(-20041, 'computeAssure error');
                end if;
                --��֤��Ӧ���ϵ�����
                v_Margin_one := v_Margin_one + v_Assure_one;
                    v_Margin:=v_Margin + v_Margin_one;
                    v_Assure:=v_Assure + v_Assure_one;
                  --����Ӧ�˳ֲֽ��������ֶ���
                  v_HoldFunds := v_HoldFunds + v_tradedAmount*v_price*v_ContractFactor;
                  end if;
                  --2������ֲ���ϸ�н��յĵֶ�����
          if(v_GageQty > 0) then
                    if(v_GageQty<=v_unCloseQtyGage) then
                        v_tradedAmountGage:=v_GageQty;
                    else
                        v_tradedAmountGage:=v_unCloseQtyGage;
                    end if;
                  end if;
              --����ǰ�ֶ�ģʽ�����ֲֽ̳��Ҫ�˵ֶ���
              if(v_GageMode=1) then
                v_HoldFunds := v_HoldFunds + v_tradedAmountGage*v_price*v_ContractFactor;
              end if;
                  --�����ͻ��ϼƽ������ֶ���
                  v_CustomerHoldFunds := v_CustomerHoldFunds + (v_tradedAmount+v_tradedAmountGage)*v_price*v_ContractFactor;
                --3�����㽻�տ���

         --�����г����������������Ƿ���ȡ���ձ�֤�� ---add by zhangjian start
         if(v_IsChargeMargin = 1 )then  --�����ȡ��֤��
          --���㽻�ձ�֤��
          v_SettlementMargin_one := FN_T_ComputeSettleMargin(v_FirmID,v_CommodityID,v_BS_Flag,v_tradedAmount+v_tradedAmountGage,v_settlePrice);
            if(v_SettlementMargin_one < 0) then
                Raise_application_error(-20042, 'ComputeSettleMargin error');
            end if;
         end if;   --add by zhangjian end


          --�����򷽽��ջ����ǰ���ղ����ս��ձ�֤��
          if(v_BS_Flag = 1) then
                v_Payout_one := FN_T_ComputePayout(v_FirmID,v_CommodityID,v_BS_Flag,v_tradedAmount+v_tradedAmountGage,v_settlePrice);
                  if(v_Payout_one < 0) then
                      Raise_application_error(-20043, 'computePayout error');
                  end if;
          end if;
          --���㽻��������
          v_Fee_one := FN_T_ComputeSettleFee(v_FirmID,v_CommodityID,v_BS_Flag,v_tradedAmount+v_tradedAmountGage,v_settlePrice);
                if(v_Fee_one < 0) then
                  Raise_application_error(-20031, 'computeFee error');
                end if;
                --����˰ǰ����ӯ��
                if(v_BS_Flag = 1) then
                    v_closeFL_one := (v_tradedAmount+v_tradedAmountGage)*(v_settlePrice-v_price)*v_contractFactor; --˰ǰӯ��
                else
                    v_closeFL_one := (v_tradedAmount+v_tradedAmountGage)*(v_price-v_settlePrice)*v_contractFactor; --˰ǰӯ��
                end if;
                --���㽻����ֵ˰,v_AddedTaxFactor��ֵ˰ϵ��=AddedTax/(1+AddedTax)
              --  v_CloseAddedTax_one := round(v_closeFL_one*v_AddedTaxFactor,2);   xief 20150811
                  v_CloseAddedTax_one := 0;
                --����˰����ӯ��
                --v_closeFL_one := v_closeFL_one - v_CloseAddedTax_one; --˰��ӯ��   duanbaodi 20150730   xief 20150811
               /* if(v_TaxInclusive = 1) then
                     --����˰ �۳���ֵ˰  duanbaodi 20150730
                     v_closeFL_one := v_closeFL_one - v_CloseAddedTax_one;
                end if ;
                */

          --�ۼƽ��
              v_Payout := v_Payout + v_Payout_one;
              v_Fee := v_Fee + v_Fee_one;
          v_CloseFL:=v_CloseFL + v_closeFL_one;  --˰��ӯ���ϼ�
          v_CloseAddedTax:=v_CloseAddedTax + v_CloseAddedTax_one;  --������ֵ˰�ϼ�
          v_SettlementMargin:=v_SettlementMargin + v_SettlementMargin_one; --���ձ�֤��ϼ� add by zhangjian
              --����ǰ�ֲּ�¼�ͽ��շ��ò��뽻�ճֲ���ϸ���������³ֲ������͵ֶ�����Ϊʵ�ʽ��յ�����
          select SEQ_T_SettleHoldPosition.nextval into v_ID from dual;
          --���ֶ������뽻�ճֲ���ϸ��
              insert into t_settleholdposition
            (id, settleprocessdate, a_holdno, a_tradeno, customerid, commodityid, bs_flag, price, holdqty, openqty, holdtime, holdmargin, firmid, gageqty, holdassure, floatingloss, settlemargin, payout, settlefee, settle_pl, settleaddedtax, settleprice, settletype, holdtype, atcleardate, MatchQuantity ,happenMATCHQTY)
              select v_ID,v_TradeDate,a_holdno, a_tradeno, customerid, commodityid, bs_flag, price, holdqty, openqty, holdtime, holdmargin, firmid, gageqty, holdassure, floatingloss,v_SettlementMargin_one,v_Payout_one,v_Fee_one,v_closeFL_one,v_CloseAddedTax_one,v_settlePrice,2, holdtype, atcleardate, holdqty, v_tradedAmount
              from t_holdposition
              where A_HoldNo=v_A_HoldNo;
           --������Խ��ճֲ���ϸ��������ϵ  add by zhangjian 2011��12��15��13:16:45 start

           insert into T_MatchSettleholdRelevance values (p_ApplyID,v_ID,v_tradedAmount,v_settlePrice,v_Payout_one,v_SettlementMargin_one);

           --end  by zhangjian 2011��12��15��13:16:55

              update T_SettleHoldPosition set HoldQty=v_tradedAmount,GageQty=v_tradedAmountGage where ID=v_ID;

                  --���³ֲּ�¼
                    update T_holdposition
                    set holdqty = holdqty - v_tradedAmount,HoldMargin=HoldMargin-v_Margin_one,HoldAssure=HoldAssure-v_Assure_one,GageQty = GageQty - v_tradedAmountGage
                    where a_holdno = v_a_holdno;

                  v_unCloseQty:=v_unCloseQty - v_tradedAmount;
                  v_unCloseQtyGage:=v_unCloseQtyGage - v_tradedAmountGage;
                  exit when v_unCloseQty=0 and v_unCloseQtyGage=0;
                end if;

       end loop;
       close v_HoldPosition;
      if(v_unCloseQty>0) then --���ճֲ��������ڿɽ��ճֲ�����
          rollback;
          return -3;
      end if;
      if(v_unCloseQtyGage>0) then --���յֶ��������ڿɵֶ�����
          rollback;
          return -4;
      end if;
    --���ٽ��׿ͻ��������̵ĳֲֺϼ���Ϣ2009-10-15
        v_num := FN_T_SubHoldSum(p_HoldQty,p_GageQty,v_Margin,v_Assure,v_CommodityID,v_ContractFactor,v_BS_Flag,v_FirmID,v_HoldFunds,v_CustomerID,v_CustomerHoldFunds,v_GageMode,p_HoldQty);

    --д�ϼƵ���ˮ
        --�۳����ջ���ͽ��ձ�֤��,ͬʱ�˱�֤��͵����� --modify by zhangjian
        update T_Firm
        set runtimemargin = runtimemargin - v_Margin,
            RuntimeAssure = RuntimeAssure - v_Assure,
            RuntimeSettleMargin = RuntimeSettleMargin + v_SettlementMargin
        where Firmid = v_FirmID;
        --���¶����ʽ��ͷŸ��˲��ֵı�֤��
    v_F_FrozenFunds := FN_F_UpdateFrozenFunds(v_FirmID,-(v_Margin-v_Assure),'15');
        --����۳����ջ����ʽ���ˮ
    v_Balance := FN_F_UpdateFundsFull(v_FirmID,'15008',v_Payout,null,v_CommodityID,null,null);
        --д���ձ�֤����ˮ add by zhangjian
        if(v_IsChargeMargin = 1 )then
    v_Balance := FN_F_UpdateFundsFull(v_FirmID,'15013',v_SettlementMargin,null,v_CommodityID,null,null);
        end if;
        --�����ʽ�,ͬʱ���뽻���������ʽ���ˮ
    --��������ѵ�����ͽ��������ѣ�����ͽ�����������ȡ�����ҽ��˽��������һ����ϸ�������Ѹ��³ɼ��ϲ���������
    if(v_ID is not null) then  --��ʾ�������гֲ����˽��գ���Ϊ���жϵ�û�гֲ�ʱҲ����ȡ��ͽ��������ѵ�
        if(v_Fee >= v_LowestSettleFee) then
            v_Balance := FN_F_UpdateFundsFull(v_FirmID,'15010',v_Fee,null,v_CommodityID,null,null);
      else
          v_Balance := FN_F_UpdateFundsFull(v_FirmID,'15010',v_LowestSettleFee,null,v_CommodityID,null,null);
            update T_SettleHoldPosition
            set SettleFee=SettleFee+(v_LowestSettleFee-v_Fee)
            where ID=v_ID;
        end if;
      end if;
    --�����ʽ�����д������ӯ�����ս��տ�����ˮ
    --��Ʒ������˰���ڽ��׹����о�����˰
   /* if(v_CloseFL >= 0) then
      v_Balance := FN_F_UpdateFundsFull(v_FirmID,'15011',v_CloseFL,null,v_CommodityID,v_CloseAddedTax,null);
    else
      v_Balance := FN_F_UpdateFundsFull(v_FirmID,'15012',-v_CloseFL,null,v_CommodityID,-v_CloseAddedTax,null);
    end if;*/
    ------xief  20150811
    if(v_CloseFL >= 0) then
      v_Balance := FN_F_UpdateFundsFull(v_FirmID,'15011',v_CloseFL,null,v_CommodityID,null,null);
    else
      v_Balance := FN_F_UpdateFundsFull(v_FirmID,'15012',-v_CloseFL,null,v_CommodityID,null,null);
    end if;

    --�洢�ϲ���  add  by  zhangjian  ��2011��12��26�� 14:52:34

    if(v_aheadSettlePriceType=0)then  --����������۽������ڴ˴�����������ݵĲ���
       select sum(m.quantity*m.price*v_ContractFactor)
       into v_totalRef
       from T_MatchSettleholdRelevance m, T_SettleHoldPosition s
       where m.settleid = s.id
       and matchid = p_ApplyID
       and bs_flag = p_BS_Flag;
       if(p_BS_Flag=1)then --������� ������µĽ����������

           --2.5 ���뽻����Ա�
         insert into T_SettleMatch (MatchID,CommodityID,ContractFactor,Quantity,HL_Amount,Status,Result,SettleType,FirmID_B,BuyPrice,BuyPayout_Ref,BuyPayout,BuyMargin,TakePenalty_B,PayPenalty_B,SettlePL_B,
               FirmID_S,SellPrice,SellIncome_Ref,SellIncome,SellMargin,TakePenalty_S,PayPenalty_S,SettlePL_S,CreateTime,ModifyTime,SettleDate)
               values (p_ApplyID,p_CommodityID,v_ContractFactor,(p_HoldQty+p_GageQty),0,0,1,2,v_FirmID,v_settlePrice,v_totalRef,v_Payout,v_settlementmargin,0,0,0,
               v_FirmID,v_settlePrice,v_totalRef,0,v_SettlementMargin,0,0,0,sysdate,sysdate,v_TradeDate);
       elsif(p_BS_Flag=2)then  --�������������½���������ݱ�
       update T_SettleMatch set FirmID_S=v_FirmID , SellPrice=v_settlePrice,SellIncome_Ref=v_totalRef,SellMargin=v_settlementmargin where MatchID=p_ApplyID;
       end if;
    elsif(v_aheadSettlePriceType=1) then
       if(p_BS_Flag=2)then --������� ������µĽ����������
           --1�������򷽽��ջ���
           select FirmID into v_bFirmID from T_Customer where CustomerID=p_OCustomerID;--�ҳ��򷽽�����ID
           v_bPayout := FN_T_ComputePayout(v_bFirmID,p_CommodityID,1,(p_HoldQty+p_GageQty),p_Price);
           if(v_bPayout < 0) then
              Raise_application_error(-20043, 'computePayout error');
           end if;
           --2�����뽻����Ա�����ǰ���ղ����㽻�ձ�֤��
           --2.��ǰ���ո����г������趨���ж��Ƿ���ȡ��֤�� -- modify by zhangjian
           select ASMarginType into v_IsChargeMargin from t_a_market;
           if(v_IsChargeMargin = 1 )then  --�����ȡ��֤��
              --�����򷽽��ձ�֤��
              v_SettlementMargin_B := FN_T_ComputeSettleMargin(v_bFirmID,p_CommodityID,1,p_HoldQty+p_GageQty,p_Price);
              if(v_SettlementMargin_B < 0) then
                 Raise_application_error(-20042, 'ComputeSettleMargin error');
              end if;
              --�����������ձ�֤��
             /* v_SettlementMargin_S := FN_T_ComputeSettleMargin(v_FirmID,p_CommodityID,2,(p_HoldQty+p_GageQty),p_Price);
              if(v_SettlementMargin_S < 0) then
                  Raise_application_error(-20042, 'ComputeSettleMargin error');
              end if;*/
           end if;   --add by zhangjian end

           --2.5 ���뽻����Ա�
           select ContractFactor into v_ContractFactor from T_Commodity where CommodityID=p_CommodityID;
           insert into T_SettleMatch (MatchID,CommodityID,ContractFactor,Quantity,HL_Amount,Status,Result,SettleType,FirmID_B,BuyPrice,BuyPayout_Ref,BuyPayout,BuyMargin,TakePenalty_B,PayPenalty_B,SettlePL_B,
           FirmID_S,SellPrice,SellIncome_Ref,SellIncome,SellMargin,TakePenalty_S,PayPenalty_S,SettlePL_S,CreateTime,ModifyTime,SettleDate)
           values (p_ApplyID,p_CommodityID,v_ContractFactor,(p_HoldQty+p_GageQty),0,0,1,2,v_bFirmID,p_Price,(p_HoldQty+p_GageQty)*p_Price*v_ContractFactor,v_bPayout,v_SettlementMargin_B,0,0,0,
           v_FirmID,p_Price,(p_HoldQty+p_GageQty)*p_Price*v_ContractFactor,0,v_SettlementMargin,0,0,0,sysdate,sysdate,v_TradeDate);
       end if;
    end if;
    return 1;

end;
/
