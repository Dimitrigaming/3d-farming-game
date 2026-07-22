using System.Collections.Generic;
using UnityEngine;

namespace HeadphoneSelector
{

    public class HeadphoneSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_HEADPHONES = 6
;
        [Range(0, MAXIMUM_NUMBER_HEADPHONES - 1)]
        public int Headphone;
        public GameObject[] Headphones = new GameObject[MAXIMUM_NUMBER_HEADPHONES];


        void OnValidate()
        {
		ValidateObject(Headphone, Headphones);

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
