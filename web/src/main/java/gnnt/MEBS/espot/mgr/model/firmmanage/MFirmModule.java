package gnnt.MEBS.espot.mgr.model.firmmanage;

import gnnt.MEBS.common.mgr.model.StandardModel;
import gnnt.MEBS.common.mgr.model.StandardModel.PrimaryInfo;
import gnnt.MEBS.common.mgr.model.translate.ClassDiscription;

public class MFirmModule
  extends StandardModel
{
  private static final long serialVersionUID = -2128172735312930898L;
  @ClassDiscription(name="交易商ID", description="")
  private String firmId;
  @ClassDiscription(name="系统模块号", description="")
  private Integer moduleID;
  @ClassDiscription(name="模块是否启用", description="模块是否启用Y：启用 N：禁用")
  private String enabled;
  
  public String getFirmId()
  {
    return this.firmId;
  }
  
  public void setFirmId(String paramString)
  {
    this.firmId = paramString;
  }
  
  public Integer getModuleID()
  {
    return this.moduleID;
  }
  
  public void setModuleID(Integer paramInteger)
  {
    this.moduleID = paramInteger;
  }
  
  public String getEnabled()
  {
    return this.enabled;
  }
  
  public void setEnabled(String paramString)
  {
    this.enabled = paramString;
  }
  
  public StandardModel.PrimaryInfo fetchPKey()
  {
    return null;
  }
}
