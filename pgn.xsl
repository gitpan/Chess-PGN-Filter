<?xml version="1.0"?>
<!-- edited with XML Spy v4.3 U (http://www.xmlspy.com) by Hugh S. Myers (private) -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<xsl:template match="/">
		<xsl:apply-templates/>
	</xsl:template>
	<xsl:template match="GAME">
		<xsl:apply-templates/>
		<HR/>
	</xsl:template>
	<xsl:template match="TAGLIST">
		<p align="CENTER">
			<xsl:apply-templates/>
		</p>
	</xsl:template>
	<xsl:template match="GAMETEXT">
		<p>
			<xsl:apply-templates/>
		</p>
	</xsl:template>
	<xsl:template match="Event">
		<xsl:call-template name="tagger"/>
	</xsl:template>
	<xsl:template match="Site">
		<xsl:call-template name="tagger"/>
	</xsl:template>
	<xsl:template match="Date">
		Date: <b>
			<xsl:value-of select="@YEAR"/>.
			<xsl:value-of select="@MONTH"/>.
			<xsl:value-of select="@DAY"/>
		</b>
		<br/>
	</xsl:template>
	<xsl:template match="Round">
		<xsl:call-template name="tagger"/>
	</xsl:template>
	<xsl:template match="White">
		<xsl:call-template name="tagger"/>
	</xsl:template>
	<xsl:template match="Black">
		<xsl:call-template name="tagger"/>
	</xsl:template>
	<xsl:template match="Result">
		<xsl:call-template name="result"/>
	</xsl:template>
	<xsl:template match="ECO">
		<xsl:call-template name="tagger"/>
	</xsl:template>
	<xsl:template match="NIC">
		<xsl:call-template name="tagger"/>
	</xsl:template>
	<xsl:template match="Opening">
		<xsl:call-template name="tagger"/>
	</xsl:template>
	<xsl:template match="POSITION">
		<p align="CENTER">
			<font>
				<xsl:attribute name="FACE"><xsl:value-of select="@FONT"/></xsl:attribute>
				<xsl:attribute name="SIZE"><xsl:value-of select="@SIZE"/></xsl:attribute>
				<xsl:for-each select="ROW">
					<xsl:value-of select="."/>
					<br/>
				</xsl:for-each>
			</font>
		</p>
	</xsl:template>
	<xsl:template match="MOVENUMBER">
		<xsl:value-of select="."/>.<xsl:text>&#x20;</xsl:text>
	</xsl:template>
	<xsl:template match="MOVE">
		<font face="FigurineSymbol S1" size="4">
			<b>
				<xsl:value-of select="."/>
				<xsl:text>&#x20;</xsl:text>
			</b>
		</font>
	</xsl:template>
	<xsl:template match="COMMENT"/>
	<xsl:template match="FENstr"/>
	<xsl:template match="GAMETERMINATION">
		<font face="Times New Roman" color="red" size="4">
			<xsl:call-template name="result"/>
		</font>
	</xsl:template>
	<xsl:template name="result">
		<xsl:choose>
			<xsl:when test="@GAMERESULT[.='WHITEWIN']">
				<b>1-0</b>
				<br/>
			</xsl:when>
			<xsl:when test="@GAMERESULT[.='BLACKWIN']">
				<b>0-1</b>
				<br/>
			</xsl:when>
			<xsl:when test="@GAMERESULT[.='DRAW']">
				<b>1/2-1/2</b>
				<br/>
			</xsl:when>
			<xsl:when test="@GAMERESULT[.='UNKNOWN']">
				<b>*</b>
				<br/>
			</xsl:when>
		</xsl:choose>
	</xsl:template>
	<xsl:template name="tagger">
		<xsl:value-of select="name()"/>: <b>
			<xsl:value-of select="."/>
		</b>
		<br/>
	</xsl:template>
</xsl:stylesheet>
