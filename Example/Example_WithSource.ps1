Configuration DismWithWrongSource {
    Import-DscResource -ModuleName xDismFeature

    Node "localhost"
    {
        xDismFeature DismFeatureWithSource1
        {
            Ensure = "Present"
            Name = "NetFx3"
            Source = "asd"
        }
    }
}

Configuration DismWithoutSource {
    Import-DscResource -ModuleName xDismFeature

    Node "localhost"
    {
        xDismFeature DismFeatureWithSource2
        {
            Ensure = "Present"
            Name = "NetFx3"
        }
    }
}

Configuration DismCorrectSource {
    Import-DscResource -ModuleName xDismFeature

    Node "localhost"
    {
        xDismFeature DismFeatureWithSource3
        {
            Ensure = "Present"
            Name = "NetFx3"
            Source = "C:\sources\sxs"
        }
    }
}

DismCorrectSource
DismWithoutSource
DismWithWrongSource
