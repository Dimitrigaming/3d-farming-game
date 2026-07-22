using System.Collections.Generic;
using UnityEngine;

namespace WatchSelector
{

    public class WatchSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_WATCHES = 16
;
        [Range(0, MAXIMUM_NUMBER_WATCHES - 1)]
        public int Watch;
        public GameObject[] Watches = new GameObject[MAXIMUM_NUMBER_WATCHES];


        void OnValidate()
        {
		ValidateObject(Watch, Watches);

        }

        public void ValidateObject(int selectedIndex, GameObject[] objects)
        {
            if (selectedIndex > objects.Length)
                selectedIndex = objects.Length;

            for (int i = 0; i < objects.Length; i++)
            {
                if (objects[i] != null)
                    objects[i].SetActive(i == selectedIndex);
            }
        }
    }
}
